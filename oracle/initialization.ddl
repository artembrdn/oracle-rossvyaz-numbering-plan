-- основная таблица с данными всех загрузок
CREATE TABLE DEF_CODES 
(
  ABCDEF NUMBER NOT NULL 
, BEGINNUM NUMBER NOT NULL 
, ENDNUM NUMBER NOT NULL 
, NUMCOUNT NUMBER 
, OPERNAME VARCHAR2(400 BYTE) 
, REGNAME VARCHAR2(400 BYTE) 
, DATE_ACT DATE 
, ABCDEF_STR VARCHAR2(20 BYTE) 
, BEGINNUM_STR VARCHAR2(20 BYTE) 
, ENDNUM_STR VARCHAR2(20 BYTE) 
, TEL1 NUMBER 
, TEL2 NUMBER 
) 
TABLESPACE DEF_CODES
PCTFREE 0 
COMPRESS 
NOPARALLEL;

CREATE INDEX DEF_CODES_TEL1 ON DEF_CODES ("TEL1" DESC, "DATE_ACT" DESC) 
TABLESPACE DEF_CODES_INDX
PCTFREE 10 
INITRANS 2 
NOPARALLEL;

--опционально( для функции LOAD_DEF.find )
CREATE INDEX DEF_CODES_RANGE ON DEF_CODES (TEL1 ASC, TEL2 ASC) 
TABLESPACE DEF_CODES_INDX 
PCTFREE 10 
INITRANS 2 
NOPARALLEL;
--------------------------------------------------------------------------------------------------------
-- секционированная таблица с ОДНОЙ партицией, для быстрого обновления актуального "снимка"
CREATE TABLE DEF_CODES_ACT 
(
  TEL VARCHAR2(4000 BYTE) 
, OPERNAME VARCHAR2(400 BYTE) 
, REGNAME VARCHAR2(400 BYTE) 
, DATE_ACT DATE 
) 
TABLESPACE DEF_CODES 
PCTFREE 0
INITRANS 1 
COMPRESS 
NOPARALLEL 
PARTITION BY RANGE (TEL) 
(
  PARTITION DEF_ACT VALUES LESS THAN (MAXVALUE) 
  NOLOGGING 
  TABLESPACE DEF_CODES 
  PCTFREE 0 
  INITRANS 1 
  STORAGE 
  ( 
    INITIAL 65536 
    NEXT 8388608 
    MINEXTENTS 1 
    MAXEXTENTS UNLIMITED 
    BUFFER_POOL DEFAULT 
  ) 
  COMPRESS NO INMEMORY  
);

CREATE UNIQUE INDEX DEF_CODES_ACT_TELON DEF_CODES_ACT (TEL ASC) 
LOCAL 
(
  PARTITION DEF_ACT 
    TABLESPACE DEF_CODES 
    PCTFREE 0 
    INITRANS 2 
    STORAGE 
    ( 
      INITIAL 65536 
      NEXT 1048576 
      MINEXTENTS 1 
      MAXEXTENTS UNLIMITED 
      BUFFER_POOL DEFAULT 
    ) 
) 
NOPARALLEL;
--------------------------------------------------------------------------------------------------------------
create or replace type def_codes_format
is object
(
  tel  varchar2(200),
  OPERNAME varchar2(400),
  regname varchar2(400),
  date_act date
);
create or replace type def_codes_type is table of def_codes_format;
          
create or replace type def_history_format
is object
(
  ID_ NUMBER, 
  FILE_NAME VARCHAR2(400 BYTE), 
  FILE_DATE_ACT date, 
  LOG VARCHAR2(4000 BYTE), 
  USER_ID NUMBER, 
  DATE_LOAD date, 
  STATUS VARCHAR2(20 BYTE)
);   
create or replace type def_history_type is table of def_history_format;
