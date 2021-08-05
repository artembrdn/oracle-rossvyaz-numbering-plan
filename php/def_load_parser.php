<?php

function log($text) {
	echo $text;
}

if( !isset( $_GET[ 'add' ] ) ){
	log('Аварийное завершение - ошибка передачи GET');
	exit(1);
}
if( $_POST[ 'file_date_act' ] == '' ) {
	log('Не указана дата актуальности файла');
	exit(1);
}
	

if( $_GET[ 'add' ] == 0 ) {
	log('Предпросмотр:');
} else {
	log('Загрузка...');
}

$valid_file = 0;
$valid_formats = array( "csv", "txt" );
if ( isset( $_FILES['text'] ) && $_SERVER[ 'REQUEST_METHOD' ] == 'POST' ) { 
    $name = $_FILES[ 'text' ][ 'name' ]; 
    $size = $_FILES[ 'text' ][ 'size' ]; 
    
    log('Файл '.$name.' ('.$size.' байт)');
    
    if ( strlen( $name ) ) {
        list( $txt, $ext ) = explode( ".", $name ); 
        if ( in_array( $ext, $valid_formats ) ) { 
            if ( $size < ( 1024 * 1024 * 40 ) ) {
				
                //заносим содержимое файла в переменную
                $tmp = $_FILES[ 'text' ][ 'tmp_name' ];
                $mass = '';
                $page='';
                $page1 = file_get_contents( $tmp );
                
                
                ini_set('display_errors',0);
                if($page=iconv('utf-8','utf-8',$page1)) {
									log('Кодировка файла UTF-8');
                }
                else {
                    if($page=iconv('windows-1251','utf-8',$page1)){
											log('Кодировка файла Windows-1251');
                    }
                    else  {
											log('Кодировка файла не подходит!');
                    }
                }
                ini_set('display_errors',1);
                
                //исправление бага файла, иногда встречаются теги &quot;
                $page = str_replace( "&quot;", " ", $page );
                $page = str_replace( "Московская область; Москва|Московская область; Москва", "Московская область, Москва|Московская область, Москва", $page );
                $page = str_replace( "Красноярский край; Республика Хакасия; г. Москва; г. Санкт-Петербург;", "Красноярский край, Республика Хакасия, г. Москва, г. Санкт-Петербург,", $page );
                
                $def = '';
								$beginnum = '';
								$endnum = '';
								$def_count = '';
								$region = '';
								$operator = '';
                
                $error_rows = '';
                $rows = explode( chr(10), $page );
                
                //производим предварительный просмотр файла или его загрузку
                //вынесенно два отдельных блока просмотра и загрузки чтобы не добавлять условия проверки на тип загрузки в тело цикла
                //------------------------------------------------------------------------------------------------------------------------
                if( $_GET[ 'add' ] == 0 ){
									$tr_list='';
									log('первые 100 строк:<br>');
									log( '<style>
											.all_tables, .all_tables td{
												border:1px solid black;
											}
										</style>');
									log( '<table class="all_tables">');
									$row_position = 0;
									
									//переменная $start_row_position = 0 или 1, для пропуска первой строки таблицы, содержащей названия столбцов
									$start_row_position = 0;
									for( $start_row_position; $start_row_position < count($rows); $start_row_position++ ){
										$string = $rows[ $start_row_position ];
										$colls = explode(';',$string);
										if( count($colls) == 6 || count($colls) == 7 ){
											$def = trim($colls[ 0 ]);
											$beginnum = trim($colls[ 1 ]);
											$endnum = trim($colls[ 2 ]);
											$def_count = trim($colls[ 3 ]);
											$region = trim($colls[ 4 ]);
											$operator = trim($colls[ 5 ]);
											
											//проверяем на битые столбцы
											if ( !is_numeric( $def ) || !is_numeric( $beginnum ) || !is_numeric( $endnum ) || !is_numeric( $def_count ) ){
												$error_rows .= 'битая строка - "'.$string.'" ошибка содержимого столбца (встретился не числовой символ)<br>';
											}else if ( strlen( $beginnum ) < 7 || strlen( $endnum ) < 7  ){
												$error_rows .= 'битая строка - "'.$string.'" ошибка содержимого столбца (неправильная длина beginnum | endnum)<br>';
											}else{
												
												//выводим первые 100 строк
												if ( $row_position < 100 )
													$tr_list .= '<tr><td width=30px>'.$def.'</td><td width=60px>'.$beginnum.'</td><td width=60px>'.$endnum.'</td><td width=60px>'.$def_count.'</td><td width=300px>'.$region.'</td><td width=300px>'.$operator.'</td></tr>';								
												$row_position++;	  
											}
											
											
										}
										else
											$error_rows .= 'битая строка - "'.$string.'" столбцов - '.count($colls).'<br>';
									}
									log( $tr_list);
									log( '</table>');
									log( 'Всего :'.$row_position.'<br>');
									log( $error_rows);
								//------------------------------------------------------------------------------------------------------------------------	
								} else if( $_GET[ 'add' ] == 1 ){
									$row_position = 0;
									$clob='';
									
									//переменная $start_row_position = 0 или 1, для пропуска первой строки таблицы, содержащей названия столбцов
									$start_row_position = 0;
									for( $start_row_position; $start_row_position < count($rows); $start_row_position++ ){
										$string = $rows[ $start_row_position ];
										$colls = explode(';',$string);
										if( count($colls) == 6 || count($colls) == 7 ){
											$def = trim($colls[ 0 ]);
											$beginnum = trim($colls[ 1 ]);
											$endnum = trim($colls[ 2 ]);
											$def_count = trim($colls[ 3 ]);
											$region = trim($colls[ 4 ]);
											$operator = trim($colls[ 5 ]);
											
											//проверяем на битые столбцы
											if ( !is_numeric( $def ) || !is_numeric( $beginnum ) || !is_numeric( $endnum ) || !is_numeric( $def_count ) ){
												$error_rows .= 'битая строка - "'.$string.'" ошибка содержимого столбца (встретился не числовой символ)<br>';
											}else if ( strlen( $beginnum ) < 7 || strlen( $endnum ) < 7  ){
												$error_rows .= 'битая строка - "'.$string.'" ошибка содержимого столбца (неправильная длина beginnum | endnum)<br>';
											}else{
												$clob .= $def.';'.$beginnum.';'.$endnum.';'.$def_count.';'.$region.';'.$operator.chr(10);
												$row_position++;	  
											}
										}
										else
											$error_rows .= 'битая строка - "'.$string.'" столбцов - '.count($colls).'<br>';
									}
									log( 'Всего cформированно: '.$row_position.' строк<br>');
									log( $error_rows);
									
									//загрузка в БД
									if( $row_position>0){
										$conn = oci_pconnect($db_user, $db_pass, $db,"UTF8");
										if (!$conn) {
											die("Внимание: Не смог подключиться к БД ");
										}
										
										
										$s=oci_parse( $conn, "begin  prin.load_def.load( '".$_SESSION['sess_id']."', ".$_SESSION['user_id'].", '".$name."', to_date('".$_POST[ 'file_date_act' ]."','dd.mm.yyyy'), :param1, :res ); end;" );
							
										oci_bind_by_name( $s, ':res', $res, 800 );
										
										$clob_ora = oci_new_descriptor( $conn, OCI_D_LOB );
										$clob_ora->WriteTemporary( $clob );
										
										oci_bind_by_name( $s, ':param1', $clob_ora, -1, OCI_B_CLOB );
										oci_execute( $s, OCI_DEFAULT );
										oci_commit( $conn );
										$clob_ora->close();
										oci_free_statement( $s );
										echo $res;
									}
								}	  
            }
            else log( "Размер файла превышает 40МБ");
         }
        else log( "Формат не подходит");
    }
    else log( "Пожалуйста выберите файл для загрузки");
}  
?>