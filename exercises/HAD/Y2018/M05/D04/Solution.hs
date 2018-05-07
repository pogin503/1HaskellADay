module Y2018.M05.D04.Solution where

{--
We're going to ease back into ETL-like functionality again. The endgame is this:
We want to create a daily upload process that:

1. Queries the database for the most recent entry into the audit logs (date)
2. Fetches a set of (articles) from the REST endpoint up to a week before (date)
3. Triages (articles) into:
   a. redundant
   b. updated
   c. new
   when compared against what's in the data store.
4. Takes the new articles and
   a. discards them
   b. updates them
   c. inserts them
   based upon their triaged state
5. Logs everything and audits the process for review and the next go-'round.

So, let's break this problem into bite-sized pieces, recollecting what we've
done before, reusing what we can, and repurposing what we can.

The vein of these Haskell problems is to use available code/algorithms, even
when data types don't quite match what we've done before.

So: 1. get the most recent audit log entry and offset that by one week.
--}

import Control.Arrow ((&&&))
import Control.Monad.Writer

import Data.Aeson
import Data.Maybe
import Data.Time

import Database.PostgreSQL.Simple

-- below imports available via 1HaskellADay git repository

import Control.DList (dlToList)

import Data.Logger
import Data.Time.Stamped

import Store.SQL.Connection

import Y2018.M01.D29.Solution (oneWeekAgo)

-- we can't use:

-- import Y2018.M01.D26.Solution (ow)

-- because that's based on PILOT data structures, not WPJ ones. We fetch
-- WPJ packets from:

import Y2018.M04.D11.Solution (PageNumber)
import Y2018.M04.D13.Solution hiding (packetReader, errOut)

-- Packet is declared in Y2018.M04.D13.Solution, but we need to convert the
-- Value values to Article values to get the date published

import Y2018.M04.D02.Solution -- for FromJSON Article

-- Say the the result of oneWeekAgo for WPJ database is (date). Did you have 
-- to change anything to get that result?

-- Okay, that was too easy.

-- 2. Fetch a set of articles from the rest endpoint upto (date)

type ParsedPacket = (Packet Value, [(Value, Article)])

pack2arts :: Packet Value -> [(Value, Article)]
pack2arts (Pack arts) = mapMaybe (r2m . (id &&& fromJSON)) arts
   where r2m (y, Success x) = Just (y, x)
         r2m _              = Nothing

-- and from there you can convert a packet to a parsed packet

packetReader :: Day -> Tries -> StampedWriter LogEntry [ParsedPacket]
packetReader = pr' 1 []

pr' :: PageNumber -> [ParsedPacket] -> Day -> Tries 
    -> StampedWriter LogEntry [ParsedPacket]
pr' pn accum day tries = if tries > 3
   then error ("Tried three times to load packet " ++ show pn ++ "; quitting")
   else lift (readPacket pn) >>=
        let nex = succ pn in
        either (accumPacket day nex accum)
               (errOut nex day (succ tries) accum)

-- this time packetReader reads all packets up to (weekAgo)

accumPacket :: Day -> PageNumber -> [ParsedPacket] -> Packet Value
            -> StampedWriter LogEntry [ParsedPacket]
accumPacket day pn accum pack =
   let arts = pack2arts pack
       newaccum = (pack, arts):accum
       today = fmap (localDay . zonedTimeToLocalTime) . date . art . snd
       downloadedDay = minimum (mapMaybe today arts) in
   if downloadedDay < day then return newaccum
   else loggerr ("Loaded packet " ++ show pn) >> pr' pn newaccum day 0

-- the accumulator function on successful read

errOut :: PageNumber -> Day -> Tries -> [ParsedPacket] -> String
       -> StampedWriter LogEntry [ParsedPacket]
errOut pn weekAgo retries accum errmsg =
   loggerr ("Error reading packet " ++ show pn ++ ": " ++ errmsg) >>
   pr' pn accum weekAgo retries

loggerr :: String -> StampedWriter LogEntry ()
loggerr msg = sayIO (Entry ERROR "daily upload" "Y2018.M05.D04.Solution" msg) >>
   lift (putStrLn msg)

-- How many packets did you consume for a week's worth of articles from today?

downloader :: IO [ParsedPacket]
downloader = connectInfo WPJ >>= connect >>= \conn ->
   oneWeekAgo conn >>= \day ->
   close conn >>
   putStrLn ("A week ago is " ++ show day) >>
   fmap fst (runWriterT (packetReader day 0))