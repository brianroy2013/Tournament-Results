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
--		wins (tracked by python code)  note it would be possible to consctruct this using DB SELECT statements but is easier to track
--		matches (tracked by python code) same note as above
CREATE TABLE players (id SERIAL PRIMARY KEY, name TEXT, wins INTEGER, matches INTEGER);

-- The matches table keeps tracks of all the matchs played so far
CREATE TABLE matches (winner INTEGER REFERENCES players(id), loser INTEGER REFERENCES players(id));


-- This view creates a table listing all of the oppenets each player has played.  The resulting table has two columns player_id and oppenet_id
-- This view is not intended to be used by itself but as part of the "player_rank" view (1st part of a three stage pipeline)
-- the "(matches.winner+matches.loser)-players.id" is used to find the id of the opp (the player won or lost and this expresion subtracts id out and
-- leaves the opp id)
CREATE VIEW opponent_id AS 
	SELECT players.id,players.wins,(matches.winner+matches.loser)-players.id AS opponent 
	FROM matches,players 
	WHERE matches.winner=players.id OR matches.loser=players.id 
	ORDER BY players.id;

-- This view creates a table with three columns id, wins, and opp_wins.  This is the 2nd stage of a three stage pipeline
CREATE VIEW player_rank AS 
	SELECT opponent_id.id, opponent_id.wins, players.wins AS opp_wins 
	FROM opponent_id,players 
	WHERE players.id=opponent_id.opponent;

-- This view is used to aggregate oppenets each player has played  this is the third (and final) stagein the pipeline.
CREATE VIEW swiss_pairings AS 
	SELECT id, max(wins) as record, sum(opp_wins) as oppenet_strength
	from player_rank 
	GROUP BY id 
	ORDER BY record DESC, oppenet_strength DESC, id ASC;

