create or replace PACKAGE LOAD_DEF AS
	
        procedure load(  sessid_ in varchar2, uid_ in number,  file_name_ in varchar2, file_date_act_ in date, input_clob_ in clob, res out varchar2 );
        procedure refresh_act(parallel_level in number default 10);
        
        function history(sessid in varchar2) return def_history_type pipelined;
        function def_codes_plane_row(tel1 in number, tel2 in number) RETURN varchar2_t pipelined parallel_enable;
        
        function find(tel in varchar2, date_stat in date  default null) return def_codes_type;
        function find_act_from_hist(tel in varchar2, date_stat in date default null) return def_codes_type;
        function find_act(tel in varchar2) return def_codes_type;
       
END LOAD_DEF;
