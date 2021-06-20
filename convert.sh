#!/bin/sh

show_infos() {
  lscpu | egrep 'Model name|Socket|Thread|NUMA|CPU\(s\)'
  sqlite3 -version
}

install_7zip() {
  sudo apt-get install p7zip-full
}

install_sqlitebiter() {
  wget https://github.com/thombashi/sqlitebiter/releases/download/v0.35.2/sqlitebiter_0.35.2_amd64.deb -O sqlitebiter.deb
  sudo dpkg -i sqlitebiter.deb
  rm sqlitebiter.deb
}

install() {
  install_7zip
  install_sqlitebiter
}

download() {
  wget https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx -O Investment_Universe.de.xlsx
}

convert() {
  DATE=$(TZ=":Europe/Berlin" date +%d_%m_%Y_%H%M)        
  SQLITE_FILE="Investment_Universe_$DATE.sqlite"
  
  sqlitebiter -v --max-workers 2 -o $SQLITE_FILE file Investment_Universe.de.xlsx
}

getFilesize() { 
  ls -sh "$1" | awk '{print $1}'; 
}

get_xlsx_filename_and_size() {        
  EXCEL_FILENAME="Investment_Universe.de.xlsx"        
  EXCEL_FILESIZE=$(getFilesize "$EXCEL_FILENAME")
}

fix_sqlite() {
  # rename_sqlite_columns
  ## the following command needs sqlite3 v3.25.x
  # - sqlite3 sqlite\*.sqlite "alter table Anlageuniversum rename column \"Anlageuniversum(Gruppe)\" to Anlagegruppe;" ".exit"
  # - sqlite3 sqlite\*.sqlite "alter table Anlageuniversum rename column \"Whitelist für institutionelle Produkte – Schweiz\" to WhitelistSchweiz;" ".exit"
  #
  # sqlite export to csv
  sqlite3 -header -csv $SQLITE_FILE "select * from Anlageuniversum;" > $SQLITE_FILE.csv
  # sed replacement on first line of file: 
  # change column name "Anlageuniversum(Gruppe)" to "Anlagegruppe"
  sed -i '1!b;s/Anlageuniversum(Gruppe)/Anlagegruppe/' $SQLITE_FILE.csv
  # sed replacement on first line of file:
  # change column name "Whitelist für institutionelle Produkte – Schweiz" to "WhitelistSchweiz"
  sed -i '1!b;s/Whitelist für institutionelle Produkte – Schweiz/WhitelistSchweiz/' $SQLITE_FILE.csv
  # change column name "IC20 Whitelist" to "WhitelistIC20"
  sed -i '1!b;s/IC20 Whitelist/WhitelistIC20/' $SQLITE_FILE.csv  
  # cleanup: delete original sqlite file, before importing to same filename
  rm $SQLITE_FILE 
  # show folder
  ls -lash
  # sqlite import csv file -> create sqlite file
  sqlite3 -csv $SQLITE_FILE ".import $SQLITE_FILE.csv Anlageuniversum"
  # cleanup: remove tmp csv file
  rm $SQLITE_FILE.csv
}

compress_sqlite() {
  # compress sqlite, get filesize
  SQLITE_ZIP_FILENAME=$SQLITE_FILE.zip
  7z a -mx9 $SQLITE_ZIP_FILENAME $SQLITE_FILE 
  SQLITE_ZIP_FILESIZE=$(getFilesize "$SQLITE_ZIP_FILENAME")
  # show folder
  ls -lash
  
  # write new README
  # ghpages uses jekyll, which has UTF-8 issues. so instead of "Ü" use "&Uuml;"
  echo -n > README.md
  echo -e '# Das gesamte [wikifolio.com Anlageuniversum](https://www.wikifolio.com/de/de/hilfe/tutorials-trader/handel-hinweise/anlageuniversum) im &Uuml;berblick:\n' >> README.md
  echo -e '\n## Excel\n' >> README.md
  echo -e '\n- [Investment_Universe.de.xlsx](https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx) ('$EXCEL_FILESIZE')\n' >> README.md
  echo -e '\n## SQLite\n' >> README.md
  echo -e '\n- ['$SQLITE_ZIP_FILENAME']('$SQLITE_ZIP_FILENAME') ('$SQLITE_ZIP_FILESIZE')\n' >> README.md
}

create_table_for_each_security_type() {
  sqlite3 $SQLITE_FILE < query/create-tables-for-securitytypes.sql 
}

export_database_for_each_security_type_table() {
  echo -e '\n#### By SecurityType\n' >> README.md  
  for SECURITYTYPE in $( sqlite3 $SQLITE_FILE "select distinct SecurityType from Anlageuniversum" ); 
  do 
    echo -e '\n-----';
    echo SecurityType: $SECURITYTYPE;
    echo Exporting to CSV file;
    sqlite3 -header -csv $SQLITE_FILE "select * from $SECURITYTYPE;" > $SECURITYTYPE-$DATE.csv;
    echo Creating SQLite for CSV file;
    sqlite3 -csv $SECURITYTYPE-$DATE.sqlite ".import $SECURITYTYPE-$DATE.csv $SECURITYTYPE";
    echo Moving CSV file into csv folder for diffing;
    mv $SECURITYTYPE-$DATE.csv csv/
    echo Create ZIP file;
    declare -A ZIP_FILENAME
    ZIP_FILENAME[$SECURITYTYPE]=$SECURITYTYPE-$DATE.sqlite.zip
    7z a -mx9 ${ZIP_FILENAME[$SECURITYTYPE]} $SECURITYTYPE-$DATE.sqlite; 
    declare -A ZIP_FILESIZE
    declare ZIP_FILESIZE[$SECURITYTYPE]=$(getFilesize ${ZIP_FILENAME[$SECURITYTYPE]});
    echo Append README.md;
    echo -e '\n- ['${ZIP_FILENAME[$SECURITYTYPE]}']('${ZIP_FILENAME[$SECURITYTYPE]}') ('${ZIP_FILESIZE[$SECURITYTYPE]}')\n' >> README.md;
    echo -e '\n-----';
  done;
}

show_cpu_info
install
download
convert
get_xlsx_filename_and_size

fix_sqlite
compress_sqlite
create_table_for_each_security_type
export_database_for_each_security_type_table
