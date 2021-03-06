{-# Language OverloadedStrings #-}

module Main where

import Data.Maybe
import Network.Connection
import Data.List.Split (splitOn)
import Data.ByteString.Char8 (unpack, pack)

connParams :: ConnectionParams
connParams =
  ConnectionParams {connectionHostname = "10.112.156.136"
                   ,connectionPort = 8080
                   ,connectionUseSecure = Nothing
                   ,connectionUseSocks = Nothing}

data Compass =
  Compass {north :: Int
          ,east :: Int
          ,south :: Int
          ,west :: Int
          ,present :: Maybe Move}
  deriving (Show,Read,Eq)

data Move
  = N
  | S
  | E
  | W
  | Done
  deriving (Show,Read,Eq)

parseMsg :: String -> Compass
parseMsg input =
  let [_:n,_:e,_:s,_:w,_:p] = splitOn " " input
      p' =
        case p of
          "?" -> Nothing
          "X" -> Just Done
          _ -> Just (read p)
  in Compass (read n)
             (read e)
             (read s)
             (read w)
             p'

clockwise :: [Move]
clockwise = N:E:S:W:clockwise

open :: Compass -> Move -> Maybe Move
open c d
  | d == N && north c > 0 = Just d
  | d == E && east  c > 0 = Just d
  | d == S && south c > 0 = Just d
  | d == W && west  c > 0 = Just d
  | otherwise = Nothing


possibleMoves :: Move -> [Move]
possibleMoves Done = []
possibleMoves c = drop 3 $ dropWhile (/= c) clockwise

openMoves :: Compass -> [Move] -> [Move]
openMoves c ms =
  catMaybes (fmap (open c) ms)

makeMove :: Move -> Compass -> Maybe Move
makeMove _ (Compass _ _ _ _ (Just Done)) = Nothing
makeMove _ (Compass _ _ _ _ (Just m)) = Just m
makeMove m c =
  case moves of
    [] -> error "Trapped! :("
    _ -> Just (head moves)
  where moves = openMoves c (possibleMoves m)

mainLoop :: (Connection, Move) -> IO (Connection, Move)
mainLoop (conn,oldMove) =
  do msg <- connectionGetLine 4096 conn
     putStr $ unpack msg ++ " -> "
     let compass = parseMsg $ unpack msg
     case makeMove oldMove compass of
       Just move ->
         do print move
            connectionPut conn $ pack $ show move
            connectionPut conn "\n"
            mainLoop (conn,move)
       Nothing ->
         do putStrLn "Done!!!"
            return (conn,Done)

main :: IO (Connection, Move)
main =
  do ctx <- initConnectionContext
     conn <- connectTo ctx connParams
     greeting <- connectionGetLine 4096 conn
     putStrLn $ unpack greeting
     connectionPut conn "haskell\n"
     mainLoop (conn,N)
