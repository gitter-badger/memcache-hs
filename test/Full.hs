{-# LANGUAGE OverloadedStrings #-}

-- | memcache test-suite.
module Main where

import           MockServer

import qualified Database.Memcache.Client as M
import           Database.Memcache.Errors
import           Database.Memcache.Socket
import           Database.Memcache.Types

import           Blaze.ByteString.Builder
import           Control.Concurrent
import           Control.Exception
import           Control.Monad
import           Data.Binary.Get
import qualified Data.ByteString.Char8 as BC
import qualified Network.Socket as N
import qualified Network.Socket.ByteString as N
import           System.Exit
import           System.IO

main :: IO ()
main = do
    -- XXX: Support port reuse for testing
    -- getTest
    -- deleteTest
    timeoutTest
    exitSuccess

getTest :: IO ()
getTest = withMCServer res $ do
    c <- M.newClient [M.def] M.def
    void $ M.set c (BC.pack "key") (BC.pack "world") 0 0
    Just (v', _, _) <- M.get c "key"
    when (v' /= "world") $ do
        putStrLn $ "bad value returned! " ++ show v'
        exitFailure 
  where
    res = [ emptyRes { resOp = ResSet Loud }
          , emptyRes { resOp = ResGet Loud "world" 0 }
          ]

deleteTest :: IO ()
deleteTest = withMCServer res $ do
    c <- M.newClient [M.def] M.def
    v1 <- M.set c "key" "world"  0 0
    v2 <- M.set c "key" "world2" 0 0
    when (v1 == v2) $ do
        putStrLn $ "bad versions! " ++ show v1 ++ ", " ++ show v2
        exitFailure
    r <- M.delete c "key" 0
    unless r $ do
        putStrLn "delete failed!"
        exitFailure
  where
    res = [ emptyRes { resOp = ResSet Loud, resCas = 1 }
          , emptyRes { resOp = ResSet Loud, resCas = 2 }
          , emptyRes { resOp = ResDelete Loud }
          ]

timeoutTest :: IO ()
timeoutTest = withMCServer res $ do
    c <- M.newClient [M.def] M.def
    void $ M.set c (BC.pack "key") (BC.pack "world") 0 0
    r <- try $ M.get c "key" 
    case r of
        Left (ClientError Timeout) -> return ()
        Left  _ -> putStrLn "unexpected exception!" >> exitFailure
        Right _ -> putStrLn "no timeout occured!" >> exitFailure
  where
    res = [ emptyRes { resOp = ResSet Loud } ]

