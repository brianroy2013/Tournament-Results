#!/usr/bin/env python
# 
# tournament.py -- implementation of a Swiss-system tournament
#

import psycopg2
import bleach

def connect():
    """Connect to the PostgreSQL database.  Returns a database connection."""
    return psycopg2.connect("dbname=tournament")

def sendSQLcommand(command,option=None):
    """Connect to the PostgreSQL database.  Executes a command and can return 
       result if reads (if option is set) 

        Args:
            command: the sql command to be executed
            option (optional): has two valid inputs
                    a) "fetchone" -> returns one result from database
                    b) "fetchall" -> retruns all the matching results from the database 
    """
    result=None
    db = connect()
    cursor = db.cursor()
    cursor.execute(command)
    if option=="fetchone":
        result=cursor.fetchone()
    if option=="fetchall":
        result=cursor.fetchall()
    db.commit()
    db.close()

    return result

def deleteMatches():
    """Remove all the match records from the database."""
    sendSQLcommand("DELETE FROM matches *;")

def deletePlayers():
    """Remove all the player records from the database."""
    sendSQLcommand("DELETE FROM players *;")

def countPlayers():
    """Returns the number of players currently registered."""
    result = sendSQLcommand("SELECT COUNT(*) FROM players;","fetchone")
    return result[0]

def registerPlayer(name):
    """Adds a player to the tournament database.
  
    The database assigns a unique serial id number for the player.  (This
    should be handled by your SQL database schema, not in your Python code.)
  
    Args:
      name: the player's full name (need not be unique).
    """
    db = connect()
    cursor = db.cursor()
    name=bleach.clean(name)
    cursor.execute("INSERT INTO players (name) VALUES (%s);", (name,))
    db.commit()
    db.close()


def playerStandings():
    """Returns a list of the players and their win records, sorted by wins.

    The first entry in the list should be the player in first place, or a player
    tied for first place if there is currently a tie.

    Returns:
      A list of tuples, each of which contains (id, name, wins, matches):
        id: the player's unique id (assigned by the database)
        name: the player's full name (as registered)
        wins: the number of matches the player has won
        matches: the number of matches the player has played
    """
    result = sendSQLcommand("SELECT * FROM player_standings;","fetchall")
    return result

def reportMatch(winner, loser):
    """Records the outcome of a single match between two players.

    Args:
      winner:  the id number of the player who won
      loser:  the id number of the player who lost
    """
    winner=bleach.clean(winner)
    loser=bleach.clean(loser)

    db = connect()
    cursor = db.cursor()
    cursor.execute("INSERT INTO matches (winner, loser) VALUES (%s,%s);", (winner,loser)) 
    db.commit()
    db.close()

def checkToSeeIfPlayedBefore(ranking):

    result=[]

    #check and see if the players have played each other before
    for index in range(0,len(ranking),2):
        p1=ranking[index][0]
        p2=ranking[index+1][0]
        string = "select * from matches where (winner=%s and loser=%s) or (winner=%s and loser=%s);" % (p1,p2,p2,p1)
        if sendSQLcommand(string,"fetchone") != None:
            print p1,p2,"played before"
            result.append(index)
            result.append(index+1)
            return result           # return the first failing pair

    return result
 
def swissPairings():
    """Returns a list of pairs of players for the next round of a match.
  
    Assuming that there are an even number of players registered, each player
    appears exactly once in the pairings.  Each player is paired with another
    player with an equal or nearly-equal win record, that is, a player adjacent
    to him or her in the standings.
  
    Returns:
      A list of tuples, each of which contains (id1, name1, id2, name2)
        id1: the first player's unique id
        name1: the first player's name
        id2: the second player's unique id
        name2: the second player's name
    """

    result = sendSQLcommand("""  SELECT players.id,players.name 
                                 FROM swiss_pairings,players 
                                 WHERE swiss_pairings.id=players.id 
                                 ORDER BY swiss_pairings.record DESC, swiss_pairings.oppenet_strength DESC, swiss_pairings.id ASC;""","fetchall")

    # "result" from the sendSQLcommand should return list of players in such a way that the pairs ((0,1),(2,3),...,(n-1,n)) should
    # never have played before.  The next bit of code checks this assumption.  If two players have played before the second player is swapped
    # with the next player in the list (i.e. if (0,1) have played then new list is ((0,2),(1,3),...)).  There is one special case for the swap
    # if the swap envolves the last elemet in the array then the swap is done with the previous pair.
    # this loop has a counter set to 100.  If unable to fix the list with 100 swaps it gives up and throws exception.
    done=False
    count=0
    while not done:
        played_before = checkToSeeIfPlayedBefore(result)
        if len(played_before) == 0:
            done=True
        else:
            p1,p2=played_before
            if p2 == len(result)-1:
                p2=p2-2
            temp = result[p2]
            result[p2] = result[p2+1]
            result[p2+1] = temp
        count=count+1
        if count>100:
            raise Exception("Some of the players have played before and was unable to fix in 100 tries")
            done=True


    pairing = []
    for index in range(0,len(result),2):
        pairing.append((result[index][0],result[index][1],result[index+1][0],result[index+1][1]))

    return pairing

