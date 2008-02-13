module OpenMath.Reply 
   ( Reply(..), replyInXML
   , ReplyOk(..), ReplyIncorrect(..), ReplyError(..)
   ) where

import Common.Context (Location)
import OpenMath.StrategyTable
import OpenMath.ObjectParser
import OpenMath.XML

------------------------------------------------------------------------
-- Data types for replies

-- There are three possible replies: ok, incorrect, or an error in the protocol (e.g., a parse error)
data Reply = Ok ReplyOk | Incorrect ReplyIncorrect | Error ReplyError
   deriving Show

data ReplyOk = ReplyOk
   { repOk_Strategy :: StrategyID
   , repOk_Location :: Location
   , repOK_Context  :: String
   , repOk_Steps    :: Int
   }
 deriving Show

data ReplyIncorrect = ReplyIncorrect
   { repInc_Strategy   :: StrategyID
   , repInc_Location   :: Location
   , repInc_Context    :: String
   , repInc_Expected   :: Expr
   , repInc_Steps      :: Int
   , repInc_Equivalent :: Bool
   }
 deriving Show
 
data ReplyError = ReplyError
   { repErr_Kind    :: String
   , repErr_Message :: String
   }
 deriving Show

------------------------------------------------------------------------
-- Conversion functions to XML
 
replyInXML :: Reply -> String
replyInXML = showXML . replyToXML

replyToXML :: Reply -> XML
replyToXML reply =
   case reply of
      Ok r        -> replyOkToXML r
      Incorrect r -> replyIncorrectToXML r 
      Error r     -> replyErrorToXML r

replyOkToXML :: ReplyOk -> XML
replyOkToXML r = xmlResult "ok" $ xmlList
   [ ("strategy", Text $ repOk_Strategy r)
   , ("location", Text $ show $ repOk_Location r)
   , ("context",  Text $ repOK_Context r)
   , ("steps",    Text $ show $ repOk_Steps r)
   ]

-- For now, show a matrix with integers
replyIncorrectToXML :: ReplyIncorrect -> XML
replyIncorrectToXML r = xmlResult "incorrect" $ xmlList
   [ ("strategy",   Text $ repInc_Strategy r)
   , ("location",   Text $ show $ repInc_Location r)
   , ("context",    Text $ repInc_Context r)
   , ("expected",   exprToXML $ repInc_Expected r)
   , ("steps",      Text $ show $ repInc_Steps r)
   , ("equivalent", Text $ show $ repInc_Equivalent r)
   ]

replyErrorToXML :: ReplyError -> XML
replyErrorToXML r = xmlResult (repErr_Kind r) [Text $ repErr_Message r]

xmlResult :: String -> [XML] -> XML
xmlResult result = Tag "reply" [("result", result), ("version", versionNr)]

xmlList :: [(String, XML)] -> [XML]
xmlList = map f
 where f (x, y) = Tag x [] [y]