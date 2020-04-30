DROP TABLE IF EXISTS MOVIMIENTO;
DROP TABLE IF EXISTS TIPOMOV;
DROP TABLE IF EXISTS PRODUCTO;
DROP TABLE IF EXISTS EMPLEADO;
DROP TABLE IF EXISTS TIPOPRO;
DROP TABLE IF EXISTS CLIENTE;
DROP TABLE IF EXISTS BANCO;
DROP TABLE IF EXISTS auditoria.auditoria;

CREATE TABLE cliente (
        cli_cc int8 not null,
        cli_nom character(60) not null, 
        cli_ape character(60), 
        cli_sex character(1),
        cli_fecnac date,
        cli_dir character(60),
        cli_tel character(60),
        PRIMARY KEY (CLI_CC));
CREATE TABLE banco (
        ban_nit int8,
        ban_nom character(20), 
        PRIMARY KEY (BAN_NIT)); 
CREATE TABLE tipopro (
        tipp_id int2 not null,
        tipp_nom character(20) not null,
        PRIMARY KEY (TIPP_ID)); 	
CREATE TABLE empleado (
        emp_cc int8 not null,
        emp_bannit int8,
        emp_nom character(60) not null, 
        emp_ape character(60), 
        emp_sex character(1),
        emp_fecnac date,
        emp_dir character(60),
        emp_tel character(60),
        PRIMARY KEY (EMP_CC));
CREATE TABLE producto (
        pro_num int8,
        pro_tippid int2, 
        pro_clicc int8,
        pro_bannit int8,
        pro_feccre date,
        pro_sal float4,
        pro_4xmil boolean,
        PRIMARY KEY (PRO_NUM));
CREATE TABLE tipomov (
        tipm_id int2,
        tipm_nom character(20),
        PRIMARY KEY (TIPM_ID));  
CREATE TABLE movimiento (
        mov_num int8,
        mov_tipmid int2, 
	mov_empcc int8,
        mov_pronum int8,
        mov_fec date,
        mov_val float4,
        PRIMARY KEY(MOV_NUM));  
		  
ALTER TABLE EMPLEADO ADD CONSTRAINT FK_EMP_BAN FOREIGN KEY (EMP_BANNIT) REFERENCES BANCO (BAN_NIT);
ALTER TABLE PRODUCTO ADD CONSTRAINT FK_PRO_BAN FOREIGN KEY (PRO_BANNIT) REFERENCES BANCO (BAN_NIT);
ALTER TABLE PRODUCTO ADD CONSTRAINT FK_PRO_CLI FOREIGN KEY (PRO_CLICC) REFERENCES CLIENTE (CLI_CC);
ALTER TABLE PRODUCTO ADD CONSTRAINT FK_PRO_TIPP FOREIGN KEY (PRO_TIPPID) REFERENCES TIPOPRO (TIPP_ID);
ALTER TABLE MOVIMIENTO ADD CONSTRAINT FK_MOV_PRO FOREIGN KEY (MOV_PRONUM) REFERENCES PRODUCTO (PRO_NUM);
ALTER TABLE MOVIMIENTO ADD CONSTRAINT FK_MOV_TIPM FOREIGN KEY (MOV_TIPMID) REFERENCES TIPOMOV (TIPM_ID);
ALTER TABLE MOVIMIENTO ADD CONSTRAINT FK_MOV_EMP FOREIGN KEY (MOV_EMPCC) REFERENCES EMPLEADO (EMP_CC);



--------------Guardar registros en la tabla auditoria---------------------
CREATE schema auditoria;
REVOKE CREATE ON schema auditoria FROM public;
 
CREATE TABLE auditoria.auditoria(
    schema_nombre text NOT NULL,
    TABLE_nombre text NOT NULL,
    user_nombre text,
    hora TIMESTAMP WITH TIME zone NOT NULL DEFAULT CURRENT_TIMESTAMP, 
    accion TEXT NOT NULL,
    dato_original text,
    dato_nuevo text
);
 
REVOKE ALL ON auditoria.auditoria FROM public;
GRANT SELECT ON auditoria.auditoria TO public;
CREATE INDEX auditoria_schema_table_idx  ON auditoria.auditoria(((schema_nombre||'.'||TABLE_nombre)::TEXT));
CREATE INDEX auditoria_hora_idx  ON auditoria.auditoria(hora);
CREATE INDEX auditoria_accion_idx ON auditoria.auditoria(accion);
CREATE OR REPLACE FUNCTION auditoria.if_modified_func() RETURNS TRIGGER AS $$
	DECLARE
		v_old_data TEXT;
		v_new_data TEXT;
	BEGIN
    IF (TG_OP = 'UPDATE') THEN
        v_old_data := ROW(OLD.*);
        v_new_data := ROW(NEW.*);
        INSERT INTO auditoria.auditoria (schema_nombre,table_nombre,user_nombre,accion,dato_original,dato_nuevo) 
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,'UPDATE',v_old_data,v_new_data);
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        v_old_data := ROW(OLD.*);
        INSERT INTO auditoria.auditoria (schema_nombre,table_nombre,user_nombre,accion,dato_original,dato_nuevo)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,'DELETE',v_old_data,v_new_data);
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT') THEN
        v_new_data := ROW(NEW.*);
        INSERT INTO auditoria.auditoria (schema_nombre,table_nombre,user_nombre,accion,dato_original,dato_nuevo)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,'INSERT',v_old_data,v_new_data);
        RETURN NEW;
    ELSE
        RAISE WARNING '[AUDITORIA.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
        RETURN NULL;
    END IF;
 
EXCEPTION
    WHEN data_exception THEN
        RAISE WARNING '[AUDITORIA.IF_MODIFIED_FUNC] - UDF ERROR [DATA EXCEPTION] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
    WHEN unique_violation THEN
        RAISE WARNING '[AUDITORIA.IF_MODIFIED_FUNC] - UDF ERROR [UNIQUE] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
    WHEN OTHERS THEN
        RAISE WARNING '[AUDITORIA.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auditoria;

CREATE TRIGGER tr_cliente AFTER INSERT OR UPDATE OR DELETE ON cliente FOR EACH ROW EXECUTE PROCEDURE auditoria.if_modified_func();
CREATE TRIGGER tr_empleado AFTER INSERT OR UPDATE OR DELETE ON empleado FOR EACH ROW EXECUTE PROCEDURE auditoria.if_modified_func();



-------trigger de ingresar y actualizar en tabla cliente-----------
create or replace function aicliente() returns trigger as
$$
	begin
		if (new.cli_cc is null) then
		     raise exception 'la cedula del cliente no puede ser nula';
		end if;
		if (new.cli_nom is null) then
		     raise exception 'El nombre del cliente no puede ser nulo';
		end if;
		if (exists(select * from cliente where cli_cc=new.cli_cc)) then
		     raise exception 'la cedula del cliente ya esta registrado';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger aicliente before insert  or update on cliente for each row execute procedure aicliente();



-------trigger de ingresar y actualizar en tabla empleado-----------
create or replace function ai() returns trigger as
$$
	begin
		if (new.emp_cc is null) then
		     raise exception 'la cedula del empleado no puede ser nula';
		end if;
		if (new.emp_nom is null) then
		     raise exception 'El nombre del empleado no puede ser nulo';
		end if;
		if (exists(select * from empleado where emp_cc=new.emp_cc)) then
		     raise exception 'la cedula del empleado ya esta registrado';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger aiempleado before insert or update on empleado for each row execute procedure aiempleado();


-------trigger de ingresar y actualizar en tabla tipoproducto-----------
create or replace function aitipoproducto() returns trigger as
$$
	begin
		if (new.tipp_id is null) then
		     raise exception 'El identificador del tipo de producto no puede ser nulo';
		end if;
		if (new.tipp_nom is null) then
		     raise exception 'El nombre del tipo de producto no puede ser nulo';
		end if;
		if (exists(select * from tipopro where tipp_id=new.tipp_id)) then
		     raise exception 'El identificador del tipo de producto ya esta registrado';
		end if;
		
	return new;
	end;
$$
language 'plpgsql';
create trigger aitipoproducto before insert or update on tipopro for each row execute procedure aitipoproducto();










insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 1 ,'José Manuel','Rozo Lopez','M', '2002/09/26','Cll 9 # 11-22','(965) 444-5235');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 2 ,'José Vicente','Guardiola Bartolomé','M', '2000/01/21','Marvá, 28','(965) 555-5235');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 3 ,'Sergio','Alcolea Alemañ','m', '2005/2/17','Ribadeo, 3','(965) 555-5235');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 4 ,'Jesús','Artero Salcedo','m', '1988/07/07','Plaza de España, 2','(91) 555-6789');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 5 ,'Natalia','Samaniego Muñoz','f', '1991/12/31','Calvo Sotelo, 42','(958) 555-3932');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 6 ,'Alberto','Túnez Rodriguez','M', '1987/4/11','Gran Via, 344','(91) 555-7355');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 7 ,'María del Prado','García Martínez','f', '1990/08/13','Castellana, 1456','(91) 555-2798');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 8 ,'Luis','Lanos','M', '1990/11/17','12, Alcazaba','(212) 555-2904');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 9 ,'María','Ramos','F', '1981/02/27','12, Paseo Hondonada','(306) 555-2246');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 10 ,'Nancy','Bustamante de Blye','F', '1992/01/17','Rambla Mendez Nuñez, 54','(96) 510-5646');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 11 ,'James','Blye','M', '1993/06/07','Rambla Mendez Nuñez, 54','(96) 510-5646');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 12 ,'Tom','Herron','M', '1995/09/01','89 Wall St.','(212) 555-3944');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 13 ,'Jesús','Fernandez García','M', '1989/03/11','Av. Constitución, 14','(212) 555-4893');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 14 ,'Helen','Peterson','f', '1991/04/22','123, Scheerdolm','(405) 555-7979');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 15 ,'Roberta','MacInche','f', '1991/12/01','72233 Avda General Perón','(965) 555-5235');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 16 ,'Francisco','Sánchez Alonso','M', '1990/06/15','Perez Galdos, 32','(914) 555-2480');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 17 ,'Ali','Zahoor','F', '1990/09/16','597 West End Ave.','(212) 555-2455');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 18 ,'Nicolas','Perez Perez','m', '1989/01/11','Diagonal, 342','(915) 555-8089');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 19 ,'Juan','Garcia Navarro','m', '1989/02/12','Plaza de los Luceros, 88','(965) 555-5235');
insert into cliente (cli_cc, cli_nom, cli_ape, cli_sex, cli_fecnac, cli_dir, cli_tel) values( 20 ,'José Luis','Pujante Martinez','M', '1990/11/13','Parque María Luisa, 23','(303) 555-3455');

insert into tipopro values( 1001 ,'Ahorros');
insert into tipopro values( 1002 ,'Corriente');
insert into tipopro values( 1003 ,'CDT');

insert into banco values( 2001 ,'Banco Bogota');
insert into banco values( 2002 ,'Banco Popular');
insert into banco values( 2003 ,'Banco BBVA');

insert into tipomov values( 1 ,'Consignacion');
insert into tipomov values( 2 ,'Retiro');
insert into tipomov values( 3 ,'Transferencia');

insert into empleado (emp_cc, emp_bannit, emp_nom, emp_ape, emp_sex, emp_fecnac, emp_dir, emp_tel) values (88123, 2001, 'Juan', 'Paz', 'M', '01/01/1970', 'Cll Av', '555-1235');
insert into empleado (emp_cc, emp_bannit, emp_nom, emp_ape, emp_sex, emp_fecnac, emp_dir, emp_tel) values (60123, 2002, 'Juana', 'de Arco', 'F', '09/07/1985', 'Cr Av', '555-1357');
insert into empleado (emp_cc, emp_bannit, emp_nom, emp_ape, emp_sex, emp_fecnac, emp_dir, emp_tel) values (10123, 2003, 'Julian', 'Roa', 'M', '05/04/1995', 'Av Cll', '555-1246');


insert into producto values( 101020 , 1001, 1, 2001,'1997/02/17', 120000, true);
insert into producto values( 101021 , 1002, 18, 2001,'1971/11/17', 12000, false);
insert into producto values( 101022 , 1001, 2, 2002,'1999/10/17', 20000, true);
insert into producto values( 101023 , 1003, 4, 2001,'1990/02/17', 10000, false);
insert into producto values( 101024 , 1002, 6, 2002,'1995/01/17', 125000, false);
insert into producto values( 101025 , 1001, 7, 2003,'1994/07/17', 205000, false);
insert into producto values( 101026 , 1002, 8, 2003,'1991/03/17', 68000, true);
insert into producto values( 101027 , 1002, 9, 2002,'1992/03/17', 1000, true);
insert into producto values( 101028 , 1001, 3, 2001,'1981/05/17', 20000, true);
insert into producto values( 101029 , 1001, 5, 2001,'1991/08/17', 1200000, false);
insert into producto values( 101030 , 1003, 20, 2003,'2000/08/27', 2500000, false);


insert into movimiento values (462415, 1, 88123, 101025, '01/02/2017', 100000);
insert into movimiento values (462416, 2, 88123, 101021, '02/04/2017', 2500000);
insert into movimiento values (462417, 3, 88123, 101022, '03/05/2017', 300000);
insert into movimiento values (462418, 1, 60123, 101027, '04/06/2017', 4900000);
insert into movimiento values (462419, 2, 60123, 101024, '05/07/2017', 100000);
insert into movimiento values (462420, 3, 60123, 101025, '06/08/2017', 2700000);
insert into movimiento values (462421, 1, 10123, 101026, '07/09/2017', 300000);
insert into movimiento values (462422, 2, 10123, 101027, '08/01/2017', 4800000);
insert into movimiento values (462423, 3, 10123, 101028, '09/02/2017', 500000);
insert into movimiento values (462424, 1, 88123, 101029, '10/03/2017', 1300000);
insert into movimiento values (462425, 2, 60123, 101027, '11/04/2017', 200000);
insert into movimiento values (462426, 1, 88123, 101020, '12/05/2017', 3100000);
