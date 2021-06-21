#!/bin/bash

export DATE=$(TZ=":Europe/Berlin" date +%d_%m_%Y_%H%M)        
export SQLITE_FILE="Investment_Universe_$DATE.sqlite"

show_infos() {
  echo -e "\nCPU Info:"
  lscpu | egrep 'Model name|Socket|Thread|NUMA|CPU\(s\)'
  echo -e "\nsqlite3 version:"
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
  # p7zip is pre-installed on github runner
  #install_7zip 
  install_sqlitebiter
}

download() {
  echo -e "\nInvestment_Universe.de.xlsx Last-Modified:"
  curl -sI https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx | grep -i Last-Modified
  # download
  wget https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx -O Investment_Universe.de.xlsx
}

convert() {
  echo -e "\nConvert xlsx to sqlite"
  sqlitebiter -v --max-workers 2 -o $SQLITE_FILE file Investment_Universe.de.xlsx
  
  echo -e "\nShow database schema"
  sqlite3 $SQLITE_FILE ".schema"
}

getFilesize() { 
  ls -sh "$1" | awk '{print $1}'; 
}

getSqliteFilename() {
  pattern="Investment_Universe_*.sqlite"
  files=( $pattern )
  echo "${files[0]}"
}

rename_sqlite_columns() {
  SQLITE_FILE=$(getSqliteFilename)
  
  # the following commands need sqlite3 v3.25.x. but we are currently (06-2021) only at v3.21 on ubuntu-latest.
  #
  # sqlite3 $SQLITE_FILE "alter table Anlageuniversum rename column \"Anlageuniversum(Gruppe)\" to Anlagegruppe;" ".exit"
  # sqlite3 $SQLITE_FILE "alter table Anlageuniversum rename column \"Whitelist für institutionelle Produkte – Schweiz\" to WhitelistSchweiz;" ".exit"
  # sqlite3 $SQLITE_FILE "alter table Anlageuniversum rename column \"IC20 Whitelist\" to WhitelistIC20;" ".exit"

  # export to temporary csv
  sqlite3 -header -csv $SQLITE_FILE "SELECT * FROM Anlageuniversum;" > $SQLITE_FILE.csv
  
  # change column names on first line of file using sed replacement
  sed -i '1!b;s/Anlageuniversum(Gruppe)/Anlagegruppe/' $SQLITE_FILE.csv  
  sed -i '1!b;s/Whitelist für institutionelle Produkte – Schweiz/WhitelistSchweiz/' $SQLITE_FILE.csv  
  sed -i '1!b;s/IC20 Whitelist/WhitelistIC20/' $SQLITE_FILE.csv  
  
  # delete original sqlite file, before importing to same filename
  rm $SQLITE_FILE 
  # create sqlite file by importing the temporary csv file
  sqlite3 -csv $SQLITE_FILE ".import $SQLITE_FILE.csv Anlageuniversum"
  # remove temporary csv file
  rm $SQLITE_FILE.csv
  
  # show folder
  ls -lash
}

compress_sqlite() { 
  SQLITE_FILE=$(getSqliteFilename)
  
  # compress sqlite, get filesize
  SQLITE_ZIP_FILENAME=$SQLITE_FILE.zip
  7z a -mx9 $SQLITE_ZIP_FILENAME $SQLITE_FILE 
  SQLITE_ZIP_FILESIZE=$(getFilesize "$SQLITE_ZIP_FILENAME")
  
  # show folder
  ls -lash
  
  EXCEL_FILENAME="Investment_Universe.de.xlsx"        
  EXCEL_FILESIZE=$(getFilesize "$EXCEL_FILENAME")
    
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
  SQLITE_FILE=$(getSqliteFilename)
  sqlite3 $SQLITE_FILE < query/create-tables-for-securitytypes.sql 
}

export_database_for_each_security_type_table() {
  SQLITE_FILE=$(getSqliteFilename)
  
  echo -e '\n#### By SecurityType\n' >> README.md  
  
  for SECURITYTYPE in $( sqlite3 $SQLITE_FILE "SELECT DISTINCT SecurityType FROM Anlageuniversum" ); 
  do 
    echo -e '\n-----';
    echo SecurityType: $SECURITYTYPE;
    
    echo -e 'Exporting data selection to CSV file';
    sqlite3 -header -csv $SQLITE_FILE "SELECT * FROM $SECURITYTYPE;" > $SECURITYTYPE-$DATE.csv;
    
    echo -e 'Creating SQLite for CSV file';
    sqlite3 -csv $SECURITYTYPE-$DATE.sqlite ".import $SECURITYTYPE-$DATE.csv $SECURITYTYPE";
    
    echo -e 'Moving CSV file into csv folder for diffing';
    mkdir -p csv
    mv $SECURITYTYPE-$DATE.csv csv/
    
    echo -e 'Create ZIP file';
    declare -A ZIP_FILENAME
    ZIP_FILENAME[$SECURITYTYPE]=$SECURITYTYPE-$DATE.sqlite.zip
    7z a -mx9 ${ZIP_FILENAME[$SECURITYTYPE]} $SECURITYTYPE-$DATE.sqlite; 
    declare -A ZIP_FILESIZE
    declare ZIP_FILESIZE[$SECURITYTYPE]=$(getFilesize ${ZIP_FILENAME[$SECURITYTYPE]});
    
    echo -e 'Append README.md';
    echo -e '\n- ['${ZIP_FILENAME[$SECURITYTYPE]}']('${ZIP_FILENAME[$SECURITYTYPE]}') ('${ZIP_FILESIZE[$SECURITYTYPE]}')\n' >> README.md;
    echo -e '\n-----';
  done;
}

show_files_and_folders() {
  # show folder: ./ 
  ls -lash
  # show folder: ./csv
  ls -lash ./csv
}

cleanup_sqlite() { 
  rename_sqlite_columns
  compress_sqlite
}

create_tables_for_each_security_type() {
  create_table_for_each_security_type
  export_database_for_each_security_type_table  
}
