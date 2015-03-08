-- Table definitions for the tournament project.
--
-- Put your SQL 'create table' statements in this file; also 'create view'
-- statements if you choose to use it.
--
-- You can write comments in this file by starting them with two dashes, like
-- these lines here.

-- This database is used to suport ...

DROP DATABASE IF EXISTS tournament;

CREATE DATABASE tournament; 
\c tournament;

-- The players table has four fieds: 
--      id (assigned by system and is the primary key)
--		name (assigned by user duplicate values are allowed)
CREATE TABLE players (id SERIAL PRIMARY KEY, name TEXT);

-- The matches table keeps tracks of all the matchs played so far
CREATE TABLE matches (winner INTEGER REFERENCES players(id), loser INTEGER REFERENCES players(id), PRIMARY KEY (winner,loser));

-- This view is used to add up all of the wins for each player (this view is used by "player_standings" view)
CREATE VIEW number_of_wins AS
	SELECT players.id, players.name, count(matches.winner) AS wins
	FROM players left join matches
	ON players.id = matches.winner
	GROUP BY players.name, players.id
	ORDER BY players.id;

-- This view is used to add up all of the losses for each player (this view is used by "player_standings" view)
CREATE VIEW number_of_losses AS
	SELECT players.id, players.name, count(matches.loser) AS lost
	FROM players left join matches
	ON players.id = matches.loser
	GROUP BY players.name, players.id
	ORDER BY players.id;

-- This is used to create a table for the players standings and has four columns
--      id (assigned by system and is the primary key)
--		name (assigned by user duplicate values are allowed)
--		wins (tracked by python code)  note it would be possible to consctruct this using DB SELECT statements but is easier to track
--		matches (tracked by python code) same note as above
CREATE VIEW player_standings AS
	SELECT number_of_wins.id, number_of_wins.name, number_of_wins.wins, (number_of_wins.wins + number_of_losses.lost) AS matches 
	FROM number_of_wins, number_of_losses 
	WHERE number_of_wins.id = number_of_losses.id 
	ORDER BY number_of_wins.id;


-- This view creates a table listing all of the oppenets each player has played.  The resulting table has two columns player_id and oppenet_id
-- This view is not intended to be used by itself but as part of the "player_rank" view (1st part of a three stage pipeline)
-- the "(matches.winner+matches.loser)-player_standings.id" is used to find the id of the opp (the player won or lost and this expresion subtracts id out and
-- leaves the opp id)
CREATE VIEW opponent_id AS 
	SELECT player_standings.id,player_standings.wins,(matches.winner+matches.loser)-player_standings.id AS opponent 
	FROM matches,player_standings 
	WHERE matches.winner=player_standings.id OR matches.loser=player_standings.id 
	ORDER BY player_standings.id;

-- This view creates a table with three columns id, wins, and opp_wins.  This is the 2nd stage of a three stage pipeline
CREATE VIEW player_rank AS 
	SELECT opponent_id.id, opponent_id.wins, player_standings.wins AS opp_wins 
	FROM opponent_id,player_standings 
	WHERE player_standings.id=opponent_id.opponent;

-- This view is used to aggregate oppenets each player has played  this is the third (and final) stage in the pipeline.
CREATE VIEW swiss_pairings AS 
	SELECT id, max(wins) as record, sum(opp_wins) as oppenet_strength
	from player_rank 
	GROUP BY id 
	ORDER BY record DESC, oppenet_strength DESC, id ASC;

