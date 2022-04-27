#! /bin/bash

if [[ $1 == "test" ]]
then
  PSQL="psql --username=postgres --dbname=worldcuptest -t --no-align -c"
else
  PSQL="psql --username=freecodecamp --dbname=worldcup -t --no-align -c"
fi

# Do not change code above this line. Use the PSQL variable above to query your database.

vCSV_FILE=/home/codeally/project/games.csv

function fn_exec_db_cmd(){
   local l_query="$1"
   local l_result

   l_result="$($PSQL "${l_query}")"
   echo "${l_result}"
}

# create tables if necessary or execute truncate to clean data
vQUERY="select exists(select from information_schema.tables where table_name='teams')"
if [ $(fn_exec_db_cmd "${vQUERY}") == "f" ]; then
   vQUERY="CREATE TABLE teams(team_id serial, name varchar(50) not null)"
   fn_exec_db_cmd "${vQUERY}"
   
   vQUERY="alter table teams add constraint teams_pk primary key(team_id)"
   fn_exec_db_cmd "${vQUERY}"

   vQUERY="ALTER TABLE TEAMS ADD CONSTRAINT TEAMS_NAME_UK UNIQUE(name)"
   fn_exec_db_cmd "${vQUERY}"

   vQUERY="\\d teams"
   fn_exec_db_cmd "${vQUERY}"
fi

vQUERY="select exists(select from information_schema.tables where table_name='games')"
if [ $(fn_exec_db_cmd "${vQUERY}") == "f" ]; then
   vQUERY="CREATE TABLE games (game_id serial, year int NOT NULL, round varchar(50) NOT NULL, winner_id int NOT NULL, winner_goals int NOT NULL, opponent_id int NOT NULL, opponent_goals int NOT NULL)"
   fn_exec_db_cmd "${vQUERY}"

   vQUERY="ALTER TABLE games ADD CONSTRAINT GAMES_PK PRIMARY KEY(game_id)"
   fn_exec_db_cmd "${vQUERY}"

   vQUERY="ALTER TABLE games ADD CONSTRAINT GAMES_WINNER_ID_FK FOREIGN KEY(winner_id) REFERENCES teams(team_id)"
   fn_exec_db_cmd "${vQUERY}"

   vQUERY="ALTER TABLE games ADD CONSTRAINT GAMES_OPPONENT_ID_FK FOREIGN KEY(opponent_id) REFERENCES teams(team_id)"
   fn_exec_db_cmd "${vQUERY}"
   vQUERY="\\d games"
   fn_exec_db_cmd "${vQUERY}"
fi

vQUERY="truncate table games, teams"
fn_exec_db_cmd "${vQUERY}"

vQUERY="alter sequence teams_team_id_seq restart with 1"
fn_exec_db_cmd "${vQUERY}"


vQUERY="alter sequence games_game_id_seq restart with 1"
fn_exec_db_cmd "${vQUERY}"


# insert data
if [ ! -f ${vCSV_FILE} ]; then
   echo "Not able to find file ${vCSV_FILE}"
   exit 1
fi

cat ${vCSV_FILE} | while IFS="," read v_year v_round v_winner v_opponent v_winner_goals v_opponent_goals
do
   if [ $v_year != "year" ]; then
      # verify if the winner/opponent team is already on table
      vQUERY="select team_id from teams where name='$v_winner'"
      v_winner_id=$(fn_exec_db_cmd "${vQUERY}")
      if [ -z $v_winner_id ]; then
         vQUERY="insert into teams(name) values('$v_winner')"
         fn_exec_db_cmd "${vQUERY}"
         vQUERY="select team_id from teams where name='$v_winner'"
         v_winner_id=$(fn_exec_db_cmd "${vQUERY}")
      fi

      vQUERY="select team_id from teams where name='$v_opponent'"
      v_opponent_id=$(fn_exec_db_cmd "${vQUERY}")
      if [ -z $v_opponent_id ]; then
         vQUERY="insert into teams(name) values('$v_opponent')"
         fn_exec_db_cmd "${vQUERY}"
         vQUERY="select team_id from teams where name='$v_opponent'"
         v_opponent_id=$(fn_exec_db_cmd "${vQUERY}")
      fi

      # insert games records
      vQUERY="insert into games(year, round, winner_id, opponent_id, winner_goals, opponent_goals) values($v_year,'$v_round',$v_winner_id,$v_opponent_id,$v_winner_goals,$v_opponent_goals)" 
      fn_exec_db_cmd "${vQUERY}"

      vQUERY="commit"  
      fn_exec_db_cmd "${vQUERY}"
   fi   
done