create or replace PACKAGE BODY LOAD_DEF AS
-- Загрузка и поиск по данным с сайта https://rossvyaz.gov.ru/deyatelnost/resurs-numeracii/vypiska-iz-reestra-sistemy-i-plana-numeracii
-----------------------------------------------------------------------------------------------------------------------------------
    --Функция получает CLOB, разбирает его по разделителю строки и столбцов и загружает в таблицу деф кодов (план нумерации)
    procedure load(sessid_ in varchar2, uid_ in number,  file_name_ in varchar2, file_date_act_ in date, input_clob_ in clob, res out varchar2 ) AS
		rows_count  pls_integer;
        res_count number;
        sq_history_id number;
	BEGIN
        --проверка прав пользователя по id сессии
        if control.check_right(sessid_, 'loader')=0 then
          return;
        end if;
        
        res := '';
        
        --логирование операции, берем уникальный id для этого
        select SQ_DEF_LOAD_HISTORY.nextval into sq_history_id from dual;
        insert into def_load_history( id_, file_name, file_date_act, user_id, date_load, status ) values (sq_history_id, file_name_, file_date_act_, uid_, SYSDATE, 'load_begin');
        commit;
        
        --Проверка и создание постоянной промежуточной таблицы (временную нельзя , т.к. производится инсерт в нее из plsql функции, не скомпилится пакет если таблица дропнута)
        select /*+ noparallel */ count(1) into rows_count from tab where tname='DEF_LOAD_REUSABLE_TABLE';
        if rows_count != 0 then
            execute immediate 'truncate table DEF_LOAD_REUSABLE_TABLE';
        else
            execute immediate 'create table DEF_LOAD_REUSABLE_TABLE ( abcdef  varchar2(20), beginnum  varchar2(20), endnum  varchar2(20), numcount number, opername varchar2(400), regname varchar2(400) ) PCTFREE 0 tablespace prin ';
            res := res||'создана постоянная таблица<br>';
        end if;
        
        select /*+ noparallel */ count(1) into rows_count from tab where tname='DEF_LOAD_REUSABLE_TABLE';
        if rows_count = 0 then
            res := res||'<a style="color:red">Мдаа... таблица все-таки не создана....</a><br>';
            update def_load_history set status='error', log=res where id_=sq_history_id;
            return;
        end if;
        
        rows_count:=0;
        --проверка загружался ли уже файл
        select /*+ noparallel */ count(1) into rows_count from def_load_history where file_name=file_name_ and file_date_act=file_date_act_ and status in ('loaded','load_begin') and id_!=sq_history_id;
        if rows_count != 0 then
            res := res||'<a style="color:red">Файл с таким именем и датой актуальности уже загружен.</a><br>';
            update def_load_history set status='error', log=res where id_=sq_history_id;
            return;
        end if;
        
        
        -- загрузка
        -- https://github.com/artembrdn/oracle-utils/blob/main/string/split_.ddl
        res := res||'Запись во временную таблицу.<br>';
        INSERT into DEF_LOAD_REUSABLE_TABLE
        select
            substr( str, 1, instr( str, ';', 1, 1 ) - 1 ) abcdef,
            substr( str, instr( str, ';', 1, 1 ) + 1, instr( str, ';', 1, 2 ) - instr( str, ';', 1, 1 ) - 1 ) beginnum,
            substr( str, instr( str, ';', 1, 2 ) + 1, instr( str, ';', 1, 3 ) - instr( str, ';', 1, 2 ) - 1 ) endnum,
            substr( str, instr( str, ';', 1, 3 ) + 1, instr( str, ';', 1, 4 ) - instr( str, ';', 1, 3 ) - 1 ) numcount,
            substr( str, instr( str, ';', 1, 4 ) + 1, instr( str, ';', 1, 5 ) - instr( str, ';', 1, 4 ) - 1 ) opername,
            substr( str, instr( str, ';', 1, 5 ) + 1 ) regname
        from table( utils.split_ ( input_clob_, chr(10) ) ) t where str is not null;
        commit;
            
        select count(1) into res_count from DEF_LOAD_REUSABLE_TABLE;
        res := res||'Записано '||res_count||' строк.<br>';
        
        INSERT INTO DEF_CODES( abcdef, beginnum, endnum, NUMCOUNT, opername, regname, date_act ,ABCDEF_STR, BEGINNUM_STR, ENDNUM_STR, TEL1, TEL2) 
        select to_number(t.abcdef), to_number(t.beginnum), to_number(t.endnum), t.NUMCOUNT, t.opername, t.regname, file_date_act_,t.abcdef, t.beginnum, t.endnum, to_number('7'||t.abcdef||t.beginnum), to_number('7'||t.abcdef||t.endnum)  from DEF_LOAD_REUSABLE_TABLE t;
            commit;
        res := res||'Все строки из временной таблицы перенесены в основную.<br>';
        
        res := '<a style="color:green">'||res||'Завершено.</a><br>';
        update def_load_history set status='loaded', log=res where id_=sq_history_id;
        return;
    exception when others then
        res := res||'<a style="color:red">error: '||sqlerrm||'</a>';
        update def_load_history set status='error', log=res where id_=sq_history_id;
        return;
    END load;
-----------------------------------------------------------------------------------------------------------------------------------
-- функция раскрывает самые актуальные диапозоны номеров и подменяет текущую партицию в таблице актуальных данных
procedure refresh_act(parallel_level in number default 10) is
    temp_tab varchar2(200) := 'TEMP_DEF_ACTS';
    table_space varchar2(200):='def_codes';
    i number;
begin
    execute immediate 'alter session set ddl_lock_timeout=1800';
	execute immediate 'alter session set sort_area_size=2147483647';
	execute immediate 'alter session set hash_area_size=2147483647';
	execute immediate 'alter session set workarea_size_policy=manual';
	execute immediate 'alter session enable parallel query';
	execute immediate 'alter session enable parallel dml';
	execute immediate 'alter session enable parallel ddl';
    
    
    execute immediate 'create table '||temp_tab||' tablespace '||table_space||' compress nologging pctfree 0
                        as 
                        select /*+ parallel('||parallel_level||')*/t1.column_value  tel , t.opername,t.regname,t.date_act
                        from DEF_CODES t, table( LOAD_DEF.def_codes_plane_row(tel1, tel2) ) t1
                        where date_act=(select max(date_act) from DEF_CODES) ';
    execute immediate 'CREATE UNIQUE INDEX '||temp_tab||'_INDEX1 ON '||temp_tab||' (TEL) tablespace '||table_space||'  parallel '||parallel_level||'';
    
    
    execute immediate 'select /*+ noparallel */ count(1) from '||temp_tab||' where rownum<10' into i;
    if i > 0 then
	       execute immediate 'alter table DEF_CODES_ACT exchange partition DEF_ACT with table '||temp_tab||' including indexes without validation';
	else
        RAISE_APPLICATION_ERROR(-20001,'Временная таблица деф кодов пустая');
    end if;
    
    execute immediate 'select /*+ noparallel */ count(1) from DEF_CODES_ACT where rownum<10' into i;
    if i > 0 then
	       execute immediate 'drop table '||temp_tab||' purge';
	end if; 

end;
-----------------------------------------------------------------------------------------------------------------------------------
--история загрузок
function history(sessid in varchar2) return def_history_type pipelined
is
	res def_history_format :=def_history_format (null, null, null, null, null, null, null) ;
begin
	if control.check_right(sessid, 'loader')=0 then
		return;
	end if;
	
  for c in  (select * from def_load_history) loop
		res.id_:=c.id_;
		res.FILE_NAME:=c.FILE_NAME;
		res.FILE_DATE_ACT:=c.FILE_DATE_ACT ;
		res.LOG:=c.LOG;
		res.USER_ID:=c.USER_ID ;
		res.DATE_LOAD:=c.DATE_LOAD ;
		res.status:=c.status;
    
		pipe row(res) ;
	end loop;
end history;
-----------------------------------------------------------------------------------------------------------------------------------
-- раскрывает диапозон на список значений
function def_codes_plane_row(tel1 in number, tel2 in number) RETURN varchar2_t pipelined parallel_enable is
	i_count number;
begin
    i_count := tel2 - tel1;
    
    for tel_i in 0..i_count loop
        pipe row(to_char(tel1+tel_i));
    end loop;
end def_codes_plane_row;
-----------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------
--простой поиск в таблице диапозонов
--single row 0.3 sec (55 uploads in table, 15 735 720 rows)
function find(tel in varchar2, date_stat in date default null) return def_codes_type
is
    res def_codes_type:= def_codes_type(null);
begin
    if ( length(tel)=11 and tel like '7%' ) then
    
        select def_codes_format(find.tel, opername,regname,date_act) bulk collect into res from(
            select /*+index(t DEF_CODES_RANGE)*/ opername,regname,date_act from def_codes t
            where to_number(tel) between tel1 and tel2
            order by date_act desc
        ) where rownum=1;
        
        return res;
    end if;  
    return res;
EXCEPTION when others then
    return res;
end;
-----------------------------------------------------------------------------------------------------------------------------------
--быстрый, но не самый очевидный способ, используется факт того что индекс отсортирован в обратном порядке
--single row 0.005 sec
function find_act_from_hist(tel in varchar2, date_stat in date default null) return def_codes_type
is
    res def_codes_type:= def_codes_type(null);
begin
    if ( length(tel)=11 and tel like '7%' ) then
        
        select  def_codes_format(find_act_from_hist.tel, opername,regname,date_act) bulk collect into res from (
                select /*+index(t DEF_CODES_TEL1)*/ * from prin.def_codes t where tel1 <=  to_number(find_act_from_hist.tel)   and date_act = date_stat   and rownum=1 order by tel1 desc, date_act desc 
        ) r where r.tel2 >= to_number(find_act_from_hist.tel);
        
        return res;
    end if;  
    return res;
exception when others then
    return res;
end;
-----------------------------------------------------------------------------------------------------------------------------------
--самый быстрый поиск по прямому совпадению в раскрытой таблице актуальных диапозонов
--single row 0.001 sec
function find_act(tel in varchar2) return def_codes_type
is
    res def_codes_type:= def_codes_type(null);
begin
    select /*+ index(t)*/ def_codes_format(find_act.tel, opername,regname,date_act) bulk collect into res from def_codes_act t
    where tel = find_act.tel;
    return res;
EXCEPTION when others then
    return res;
end;
-----------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------
END LOAD_DEF;
