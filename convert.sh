#!/bin/bash

#
# How to run: `. ./convert.sh && show_info`
#

# === Constants ===
#
#

DATE=$(TZ=":Europe/Berlin" date "+%d_%m_%Y_%H%M")
DATE_LONG=$(TZ=":Europe/Berlin" date "+%A %d.%m.%Y %H:%M")

export DATE
export DATE_LONG

SQLITE_FILE="Investment_Universe-$DATE.sqlite"
CSV_FILE="Investment_Universe-$DATE.csv"

export SQLITE_FILE
export CSV_FILE

# === Helper functions ===
#

isCISystem() {
  if [ -n "${CI}" ] && [ "${CI}" != "false" ]; then
    return 0
  else
    return 1
  fi
}

# Returns the size of a file in a human-readable format.
#
# Arguments:
#   $1: The name of the file to get the size of. Can include wildcards.
#
# Returns:
#   The size of the file(s) in a human-readable format.
#
# Example:
#   To get the size of a file called "file.txt":
#   getFilesize "file.txt"
#
getFilesize() {
  find . -name "$1" -printf "%s\n" | \
  awk '{split("B KB MB GB TB",units); for(i=1; $1>1024 && i<length(units); i++) $1/=1024; printf "%.0f %s\n", $1, units[i]}' | \
  sed 's/^[[:space:]]*//g'
}

getSqliteFilename() {
  ls Investment_Universe-*.sqlite
}

# Prints an error message in red color with optional indentation.
#
# Arguments:
#   $1: The error message to print. Defaults to "Mistakes were made."
#   $2: The indentation level. Defaults to 0 (no indentation).
#       1 = ident with 2 spaces, 2 indent with 4, 3=6, 4=8 (max.).
#
# Returns:
#   None.
#
# Example:
#   print_error "Error occurred." 1
#
print_error() {
  # Message
  local error_message=${1:-"Mistakes were made."}

  # Indent Levels (0=0, 1=2spaces, 2=4 spaces)
  local indent_level=${2:-0}
  local indent_spaces=$((indent_level > 4 ? 8 : indent_level * 2))

  # Red color code
  local red='\033[0;31m'
  local nocolor='\033[0m'

  printf "%${indent_spaces}s${red}%s${nocolor}\n" "" "$error_message"
}

# Prints a status message with optional color and indentation.
#
# Usage: print_status "Updating data..." 1 yellow
#
# Arguments:
#   $1: The message to print. Defaults to "Status update."
#   $2: The indentation level. Defaults to 0 (no indentation).
#       1 = ident with 2 spaces, 2 indent with 4, 3=6, 4=8 (max.).
#   $3: The color to use. Defaults to light grey. Possible values are:
#        "red": indicates an error or failure
#        "yellow": indicates a warning or continuation
#        "green": indicates success or completion
#        "blue": indicates information or explanation
#        "purple": indicates a special or unusual condition
#        "cyan": indicates a note or comment
#
# Returns:
#   None.
print_status() {
  # Message
  local status_message=${1:-"Status update."}

  # Indention Levels (0=0, 1=2spaces, 2=4 spaces)
  local indent_level=${2:-0}
  local indent_spaces=$((indent_level > 4 ? 8 : indent_level * 2))

  # Color codes, defaults to light grey
  local color=""
  case "${3:-}" in
    "red") color='\033[0;31m';;
    "yellow") color='\033[0;33m';;
    "green") color='\033[0;32m';;
    "blue") color='\033[0;34m';;
    "purple") color='\033[0;35m';;
    "cyan") color='\033[0;36m';;
    *) color='\033[0;37m';; # light grey
  esac
  local nocolor='\033[0m'

  # Print the message with the specified color and indentation
  printf "%${indent_spaces}s${color}%s${nocolor}\n" "" "$status_message"
}

# ---------------------------------------------------------

isInstalled() {
  if [ "$($1 2>&1 >/dev/null)" ]; then
    print_status "Already installed. Skipping."
    return 0
  else
    return 1
  fi
}

install_csvdiff() {
  print_status "🔽 Installing CSVDiff"
  isInstalled "$(csvdiff --version)" && return

  url="https://github.com/aswinkarthik/csvdiff/releases/download/v1.4.0/csvdiff_1.4.0_linux_64-bit.deb";
  # --retry-all-errors only supported by curl v7.71.0+
  curl --retry 3 -L --output ./csvdiff.deb "$url"
  sudo dpkg -i csvdiff.deb
}

install_wiuc() {
  print_status "🔽 Installing Wikifolio Universe Converter"
  isInstalled "$(data/wiuc --version)" && return

  local version
  local url
  version="$(curl -s https://api.github.com/repos/jakoch/wikifolio_universe_converter/releases/latest | jq -r '.tag_name' | cut -c 2-)"; echo "Latest WIUC Version: $version"
  url="https://github.com/jakoch/wikifolio_universe_converter/releases/download/v$version/wiuc-$version-clang17-x64-linux.zip"; echo "Download URL: $url"
  # --retry-all-errors only supported by curl v7.71.0+
  curl --retry 3 -L --output ./wiuc.zip "$url"
  mkdir -p data
  7z e ./wiuc.zip -odata  
  rm ./wiuc.zip
  chmod +x data/wiuc
}

install_7zip() {
  print_status "🔽 Installing 7zip"
  isInstalled "$(7z --help)" && return
  sudo apt-get install -y p7zip-full
}

install_jq() {
  print_status "🔽 Installing jq"
  isInstalled "$(jq --help)" && return
  sudo apt-get install -y jq
}

install_sqlite() {
  print_status "🔽 Installing sqlite"
  isInstalled "$(sqlite3 -version)" && return
  sudo apt-get install -y sqlite3
}

install_curl() {
  print_status "🔽 Installing curl"
  isInstalled "$(curl --help)" && return
  sudo apt-get install -y curl
}

install() {
  install_curl
  install_sqlite
  install_wiuc
  install_7zip
  install_csvdiff
  install_jq
}

show_infos() {
  print_status "CPU Info:" 0 blue
  lscpu | grep -E 'Model name|Socket|Thread|NUMA|CPU\(s\)'
  print_status "Tools:" 0 blue
  print_status "sqlite3 version:"
  sqlite3 --version
  print_status " "
  csvdiff --version
  7z | head -2
  jq --version
  data/wiuc --version
}

prepare_data_folder()
{
  cd data || return

  # Delete the old readme
  rm -rf README.md

  # Delete the old sqlite files, we are currently not processing them
  rm -rf sqlite/*.sqlite.zip

  # Note: at this point the old "csv/*.csv.zip" are still present
  # These files are deleted in unzip_csv_files()

  cd ..
}

convert() {
  cd data || return

  print_status "Convert xlsx to sqlite and csv using wiuc"
  ./wiuc --convert

  print_status "Adding date and time to filenames"
  mv Investment_Universe.sqlite "$SQLITE_FILE"
  mv Investment_Universe.csv "$CSV_FILE"

  # show folder
  ls -lash

  print_status "Current SQLITE SCHEMA:"
  sqlite3 "$SQLITE_FILE" ".schema"

  cd ..
}

# compresses the xlsx and sqlite investment universe files
# creates readme with download links
compress() {
  cd data || return

  SQLITE_FILE=$(getSqliteFilename)

  # compress sqlite, get filesize
  SQLITE_ZIP_FILENAME="$SQLITE_FILE.zip"
  7z a -mx9 "$SQLITE_ZIP_FILENAME" "$SQLITE_FILE"
  SQLITE_ZIP_FILESIZE=$(getFilesize "$SQLITE_ZIP_FILENAME")

  # show folder
  ls -lash

  # get filesize of xlsx
  EXCEL_FILENAME="Investment_Universe.de.xlsx"
  EXCEL_FILESIZE=$(getFilesize "$EXCEL_FILENAME")
  rm Investment_Universe.de.xlsx

  # write new README
  # ghpages uses jekyll, which has UTF-8 issues. so instead of "Ü" use "&Uuml;"
  # old URL: https://www.wikifolio.com/de/de/hilfe/tutorials-trader/handel-hinweise/anlageuniversum
  {
    echo -n;
    echo -e '# Das gesamte [wikifolio.com Anlageuniversum](https://help.wikifolio.com/article/102-welche-werte-kann-ich-im-wikifolio-handeln) im &Uuml;berblick:\n';
    echo -e '\n### Downloads vom '"$DATE"'\n';
    echo -e '| | XLSX | SQLite | CSV |';
    echo -e '|--|--|--|--|';
    echo -e '| **Investment Universe** | [xlsx](https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx) ('"$EXCEL_FILESIZE"') | [sqlite]('sqlite/"$SQLITE_ZIP_FILENAME"') ('"$SQLITE_ZIP_FILESIZE"') | |';
  } >> README.md
  cd ..
}

create_databases() {
  cd data || return

  SQLITE_FILE=$(getSqliteFilename)

  print_status 'Create tables for each SecurityType in main sqlite file'
  sqlite3 "$SQLITE_FILE" < ../query/create-tables-for-securitytypes.sql

  print_status 'Exporting SecurityType tables into sqlite database files'

  echo -e '| *By Security Type* ||||' >> README.md

  for SECURITYTYPE in $( sqlite3 "$SQLITE_FILE" "SELECT DISTINCT SecurityType FROM Anlageuniversum" );
  do
    print_status '----- SecurityType: '"$SECURITYTYPE"'';

    FILENAME=$SECURITYTYPE-$DATE

    print_status 'Exporting data selection to CSV file';
    sqlite3 -header -csv "$SQLITE_FILE" "SELECT * FROM $SECURITYTYPE;" > "$FILENAME.csv";

    print_status 'Zipping CSV file';
    declare -A CSV_FILENAME
    CSV_FILENAME[$SECURITYTYPE]=$FILENAME.csv.zip
    7z a -mx9 "${CSV_FILENAME[$SECURITYTYPE]}" "$FILENAME.csv";
    declare -A CSV_FILESIZE
    CSV_FILESIZE[$SECURITYTYPE]=$(getFilesize "${CSV_FILENAME[$SECURITYTYPE]}");
    declare CSV_FILESIZE

    print_status 'Creating SQLite for CSV file';
    sqlite3 -csv "$FILENAME.sqlite" ".import $FILENAME.csv $SECURITYTYPE";

    print_status 'Zipping SQLite file';
    declare -A ZIP_FILENAME
    ZIP_FILENAME[$SECURITYTYPE]=$FILENAME.sqlite.zip
    7z a -mx9 "${ZIP_FILENAME[$SECURITYTYPE]}" "$FILENAME.sqlite";
    declare -A ZIP_FILESIZE
    ZIP_FILESIZE[$SECURITYTYPE]=$(getFilesize "${ZIP_FILENAME[$SECURITYTYPE]}");
    declare ZIP_FILESIZE

    print_status 'Append README.md';
    echo -e '| **'"$SECURITYTYPE"'** |  | [sqlite]('sqlite/"${ZIP_FILENAME[$SECURITYTYPE]}"') ('"${ZIP_FILESIZE[$SECURITYTYPE]}"') | [csv]('csv/"${CSV_FILENAME[$SECURITYTYPE]}"') ('"${CSV_FILESIZE[$SECURITYTYPE]}"') |' >> README.md;
  done;

  cd ..
}

unzip_old_csv_files() {
  cd data || return

  # we do not handle the Derivatives, because of large daily changesets (Daily Options)
  print_status 'Unzipping CSV files' 0 blue;
  unzip 'csv/ETF-*.csv.zip' -d 'csv/old'
  unzip 'csv/Stock-*.csv.zip' -d 'csv/old'
  unzip 'csv/Wikifolios-*.csv.zip' -d 'csv/old'

  # delete all old "csv.zip" files
  rm -rf csv/*.csv.zip

  cd ..
}

diff_csv_files() {
  cd data || return

  print_status 'Diffing CSV files' 0 blue

  DIFF_SUMMARY_FILE="Diff-Summary-$DATE.json"

  for SECURITYTYPE in ETF Stock Wikifolios; do # Derivaties excluded

    print_status "Finding CSV files for $SECURITYTYPE" 1
    OLD_CSV=$(find . -wholename "./csv/old/$SECURITYTYPE-*.csv" -printf '%T@ %p\n' | sort -n | tail -n1 | cut -d' ' -f2-)
    NEW_CSV=$(find . -wholename "./$SECURITYTYPE-*.csv" -printf '%T@ %p\n' | sort -n | tail -n1 | cut -d' ' -f2-)

    if [ ! -f "$OLD_CSV" ] || [ ! -f "$NEW_CSV" ]; then
      print_error "Error: File not found. File $OLD_CSV $NEW_CSV does not exist." 1
      continue
    fi

    print_status "Diffing CSV files for $SECURITYTYPE ($NEW_CSV <-> $OLD_CSV )" 1
    DIFF_FILE="$SECURITYTYPE-$DATE-Diff.json"
    # the diffing order is important: first arg new, second arg old.
    csvdiff "$NEW_CSV" "$OLD_CSV" -o=json > "$DIFF_FILE"
    print_status "Created Diff file: $DIFF_FILE" 1 yellow

    # csvdiff returns no content, if files are identical (= no file difference).
    if ! [ -s "$DIFF_FILE" ]; then
      # Diff File is empty or does not exist.
      print_status "No Changes detected." 2 yellow
      # Create Empty JSON diff file
      SUMMARY_JSON="{ Additions: [], Modifications: [], Deletions: [] }"
      echo "$SUMMARY_JSON" > "$DIFF_FILE"
    fi

    print_status 'Calculate Changes Summary and add to diff file' 1
    SUMMARY_JSON=$(jq '{ Additions: .Additions | length, Modifications: .Modifications | length, Deletions: .Deletions | length }' "$DIFF_FILE")
    SUMMARY_JSON_FILE=$(jq --argjson SUMMARY "$SUMMARY_JSON" '.Summary |= $SUMMARY' "$DIFF_FILE")
    echo "$SUMMARY_JSON_FILE" > "$DIFF_FILE"
    # apply 2 space idention to the json file
    FORMATTING=$(jq '.' --indent 2 "$DIFF_FILE")
    echo "$FORMATTING" > "$DIFF_FILE"
    #
    # "jq -c ." = output without any whitespace

    print_status "Add Changes Summary to $DIFF_SUMMARY_FILE" 1
    if ! [ -f "$DIFF_SUMMARY_FILE" ]; then
      # Create a new JSON object with the desired key-value pair
      echo "{\"$SECURITYTYPE\": $SUMMARY_JSON}" >> "$DIFF_SUMMARY_FILE"
    else
      # Add the new key-value pair to the existing JSON object
      SUMMARY_JSON_FILE=$(jq --arg SECURITYTYPE "$SECURITYTYPE" --argjson SUMMARY_JSON "$SUMMARY_JSON" '. += {($SECURITYTYPE): $SUMMARY_JSON}' "$DIFF_SUMMARY_FILE")
      echo "$SUMMARY_JSON_FILE" > "$DIFF_SUMMARY_FILE"
    fi
  done

  print_status "Calculate Overall Summary for $DIFF_SUMMARY_FILE" 1 yellow
  TOTAL_OUT=$(jq '.Totals = {"Additions": ([.ETF, .Stock, .Wikifolios] | map(.Additions) | add), "Modifications": ([.ETF, .Stock, .Wikifolios] | map(.Modifications) | add), "Deletions": ([.ETF, .Stock, .Wikifolios] | map(.Deletions) | add)}' "$DIFF_SUMMARY_FILE")
  echo "$TOTAL_OUT" > "$DIFF_SUMMARY_FILE"

  #jq . "$DIFF_SUMMARY_FILE"

  print_status "Done" 0 green

  cd ..
}

move_files() {
  cd data || return

  print_status "Moving files" 0 blue;

  print_status 'Moving *.csv.zip file into csv folder';
  mkdir -p csv
  mv ./*.csv.zip csv/

  print_status 'Moving *.sql.zip files into sqlite folder';
  mkdir -p sqlite
  mv ./*.sqlite.zip sqlite/

  print_status 'Moving *.json files into json folder';
  mkdir -p json
  mv ./*.json json/

  cd ..
}

delete_files() {
  cd data || return

    print_status 'Deleting *.csv and *.sqlite files' 0 blue;
    rm ./*.csv
    rm ./*.sqlite
    rm -rf csv/old

    if isCISystem; then
      print_status 'Deleting wiuc'
      rm -rf wiuc
    fi

  cd ..
}

show_folders() {
  print_status 'Listing folders' 0 blue
  ls -lash ./
  ls -lash data
  ls -lash data/csv
  ls -lash data/sqlite
  ls -lash data/json
}

# do a git checkout of gh_pages branch into the data folder
# this step replicates the checkout step in the github workflow
checkout_ghpages()
{
  print_status "Checkout of gh-pages branch into data folder" 0 blue

  print_status "Initializing the repository"
  git init data
  cd data || return
  git remote add origin https://github.com/jakoch/wikifolio_universe

  print_status "Disabling automatic garbage collection"
  git config --local gc.auto 0

  print_status "Fetching the repository"
  git fetch --no-tags --prune --progress --no-recurse-submodules --depth=1 origin +refs/heads/gh-pages*:refs/remotes/origin/gh-pages* +refs/tags/gh-pages*:refs/tags/gh-pages*

  print_status "Determining the checkout info"
  git branch --list --remote origin/gh-pages

  print_status "Checking out the ref"
  git checkout --progress --force -B gh-pages refs/remotes/origin/gh-pages

  GIT_SHORT_HASH_DATE=$(git log -1 --format='%h (%ad)' --date=iso)

  print_status "/data -> branch: gh-pages @ $GIT_SHORT_HASH_DATE" 0 green

  cd ..
}

run() {
  if ! isCISystem; then
    checkout_ghpages
  fi

  install
  show_infos

  prepare_data_folder
  unzip_old_csv_files

  convert
  compress

  create_databases

  diff_csv_files

  move_files
  delete_files

  show_folders
}
