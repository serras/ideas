-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- Exercise for the logic domain: to prove two propositions equivalent
--
-----------------------------------------------------------------------------
module Domain.Logic.Proofs (proofExercise) where

import Common.Classes
import Prelude hiding (repeat)
import Common.Context
import Common.Rewriting
import Common.Rewriting.Term hiding (Var)
import Common.Strategy hiding (fail, not)
import Common.Exercise
import Common.Utils
import Common.Transformation
import Common.Navigator
import Data.List hiding (repeat)
import Control.Monad
import Domain.Logic.Formula
import Domain.Logic.Generator (equalLogicA)
import Domain.Logic.Parser
import Domain.Logic.Rules
import Domain.Logic.Examples 
import Domain.Logic.Strategies
import Domain.Math.Expr ()
import Common.Uniplate

see :: Int -> IO ()
see n = printDerivation proofExercise (examples proofExercise !! n)

-- Currently, we use the DWA strategy
proofExercise :: Exercise [(SLogic, SLogic)]
proofExercise = makeExercise
   { exerciseId     = describe "Prove two propositions equivalent" $
                         newId "logic.proof"
   , status         = Experimental
--   , parser         = parseLogicProof
   , prettyPrinter  = let f (p, q) = ppLogicPars p ++ " == " ++ ppLogicPars q
                      in commaList . map f
--   , equivalence    = \(p, _) (r, s) -> eqLogic p r && eqLogic r s
--   , similarity     = \(p, q) (r, s) -> equalLogicA p r && equalLogicA q s
   , isSuitable     = all (uncurry eqLogic)
   , isReady        = all (uncurry equalLogicA)
   , strategy       = proofStrategy
   , navigation     = termNavigator
   , examples       = map return $ exampleProofs ++
                      let p = Var (ShowString "p") 
                          q = Var (ShowString "q")
                      in [(q :&&: p, p :&&: (q :||: q))]
   }

instance (IsTerm a, IsTerm b) => IsTerm (a, b) where
   toTerm (a, b) = binary tupleSymbol (toTerm a) (toTerm b)
   fromTerm term =
      case getConSpine term of
         Just (s, [a, b]) | s == tupleSymbol ->
            liftM2 (,) (fromTerm a) (fromTerm b)
         _ -> fail "not a tuple"
   
tupleSymbol :: Symbol
tupleSymbol = newSymbol "basic.tuple"

proofStrategy :: LabeledStrategy (Context [(SLogic, SLogic)])
proofStrategy = label "proof equivalent" $ 
   repeat (somewhere (useC commonExprAtom)) <*>
   repeat (somewhere (use topIsNot <|> use topIsAnd <|> use topIsOr
             <|> use topIsImpl <|> use topIsEquiv)) <*>
   repeat (somewhere (use notDNF <*> mapRules useC dnfStrategyDWA)) <*>
   simpler <*>
   repeat (somewhere (use topIsNot <|> use topIsAnd <|> use topIsOr -- again..
             <|> use topIsImpl <|> use topIsEquiv)) <*> 
   repeat (somewhere (use normLogicRule))
 where
   simpler :: Strategy (Context [(SLogic, SLogic)])
   simpler = repeat $ somewhere $
      use tautologyOr <|> use idempotencyAnd <|> use contradictionAnd
      <|> use absorptionSubset <|> use fakeAbsorption <|> use fakeAbsorptionNot
      <|> alternatives (map use list)
            
   list = [ ruleFalseZeroOr, ruleTrueZeroOr, ruleIdempOr
          , ruleAbsorpOr, ruleComplOr
          ]

   notDNF :: Rule SLogic
   notDNF = minorRule $ makeSimpleRule "not-dnf" $ \p ->
      if isDNF p then Nothing else Just p

onceLeft :: IsStrategy f => f (Context a) -> Strategy (Context a)
onceLeft s = ruleMoveDown <*> s <*> ruleMoveUp
 where
   ruleMoveDown = minorRule $ makeSimpleRuleList "MoveDown" (down 1)   
   ruleMoveUp   = minorRule $ makeSimpleRule "MoveUp" safeUp
   
   safeUp a = maybe (Just a) Just (up a)
   
onceRight :: IsStrategy f => f (Context a) -> Strategy (Context a)
onceRight s = ruleMoveDown <*> s <*> ruleMoveUp
 where
   ruleMoveDown = minorRule $ makeSimpleRuleList "MoveDown" (down 2)   
   ruleMoveUp   = minorRule $ makeSimpleRule "MoveUp" safeUp
   
   safeUp a = maybe (Just a) Just (up a)

testje :: Rule (Context SLogic)
testje = makeSimpleRule "testje" $ \a -> error $ show a

go n = printDerivation proofExercise [exampleProofs !! n] --(p :||: Not p, Not F)
 --where p = Var (ShowString "p")
 
normLogicRule :: Rule (SLogic, SLogic)
normLogicRule = makeSimpleRule "Normalize" $ \tuple@(p, q) -> do
   guard (p /= q)
   let xs  = sort (varsLogic p `union` varsLogic q)
       new = (normLogicWith xs p, normLogicWith xs q)
   guard (tuple /= new)
   return new

-- Find a common subexpression that can be treated as a box
commonExprAtom :: Rule (Context (SLogic, SLogic))
commonExprAtom = makeSimpleRule "commonExprAtom" $ withCM $ \(p, q) -> do 
   let f  = filter same . filter ok . nub . sort . universe 
       xs = f p `intersect` f q -- todo: only largest common sub expr
       ok (Var _) = False
       ok (Not a) = ok a
       ok _       = True
       same cse = eqLogic (sub cse p) (sub cse q)
       new = head (vars \\ (varsLogic p `union` varsLogic q))
       sub a this
          | a == this = Var new
          | otherwise = descend (sub a) this
   case xs of 
      hd:_ -> do modifyVar substVar ((show new, show hd):)
                 return (sub hd p, sub hd q)
      _ -> fail "not applicable"
   
substVar :: Var [(String, String)]
substVar = newVar "subst" []
   
vars :: [ShowString]
vars = [ ShowString [c] | c <- ['a'..] ]

normLogic :: Ord a => Logic a -> Logic a
normLogic p = normLogicWith (sort (varsLogic p)) p 
   
normLogicWith :: Eq a => [a] -> Logic a -> Logic a
normLogicWith xs p = make (filter keep (subsets xs))
 where
   keep ys = evalLogic (`elem` ys) p
   make = makeOrs . map atoms
   atoms ys = makeAnds [ f (x `elem` ys) (Var x) | x <- xs ]
   f b = if b then id else Not
   
makeOrs  xs = if null xs then F else foldr1 (:||:) xs
makeAnds xs = if null xs then T else foldr1 (:&&:) xs


-- p \/ q \/ ~p     ~> T           (propageren)
tautologyOr :: Rule SLogic 
tautologyOr = makeSimpleRule "tautologyOr" $ \p -> do
   let xs = disjunctions p
   guard (any (\x -> Not x `elem` xs) xs)
   return T

-- p /\ q /\ p      ~> p /\ q
idempotencyAnd :: Rule SLogic
idempotencyAnd = makeSimpleRule "idempotencyAnd" $ \p -> do
   let xs = conjunctions p
       ys = nub xs
   guard (length ys < length xs)
   return (makeAnds ys)

-- p /\ q /\ ~p     ~> F           (propageren)
contradictionAnd :: Rule SLogic
contradictionAnd = makeSimpleRule "contradictionAnd" $ \p -> do
   let xs = conjunctions p
   guard (any (\x -> Not x `elem` xs) xs)
   return F

-- (p /\ q) \/ ... \/ (p /\ q /\ r)    ~> (p /\ q) \/ ...
--    (subset relatie tussen rijtjes: bijzonder geval is gelijke rijtjes)
absorptionSubset :: Rule SLogic
absorptionSubset = makeSimpleRule "absorptionSubset" $ \p -> do
   let xss = map conjunctions (disjunctions p)
       yss = nub $ filter (\xs -> all (ok xs) xss) xss
       ok xs ys = not (ys `isSubsetOf` xs) || xs == ys
   guard (length yss < length xss)
   return $ makeOrs (map makeAnds yss)
   
-- p \/ ... \/ (~p /\ q /\ r)  ~> p \/ ... \/ (q /\ r)
--    (p is hier een losse variabele)
fakeAbsorption :: Rule SLogic
fakeAbsorption = makeSimpleRuleList "fakeAbsorption" $ \p -> do
   let xs = disjunctions p
   v <- [ a | a@(Var _) <- xs ]
   let ys  = map (makeAnds . filter (/= Not v) . conjunctions) xs
       new = makeOrs ys
   guard (p /= new)
   return new

-- ~p \/ ... \/ (p /\ q /\ r)  ~> ~p \/ ... \/ (q /\ r)
--   (p is hier een losse variabele)
fakeAbsorptionNot :: Rule SLogic
fakeAbsorptionNot = makeSimpleRuleList "fakeAbsorptionNot" $ \p -> do
   let xs = disjunctions p
   v <- [ a | Not a@(Var _) <- xs ]
   let ys  = map (makeAnds . filter (/= v) . conjunctions) xs
       new = makeOrs ys
   guard (p /= new)
   return new

topIsNot :: Rule (SLogic, SLogic)
topIsNot = makeSimpleRule "top-is-not" f
 where
   f (Not p, Not q) = Just (p, q)
   f _ = Nothing

acTopRuleFor :: IsId a => a -> Operator SLogic -> Rule [(SLogic, SLogic)]
acTopRuleFor s op = makeSimpleRuleList s f
 where
   f [(lhs, rhs)] = do
      let xs   = collectWithOperator op lhs
          ys   = collectWithOperator op rhs
          make = buildWithOperator op
      guard (length xs > 1 && length ys > 1)
      list <- liftM (map $ \(x, y) -> (make x, make y)) (recAC xs ys)
      guard (all (uncurry eqLogic) list)
      return list
   f _ = []

topIsAnd :: Rule [(SLogic, SLogic)]
topIsAnd = acTopRuleFor "top-is-and" andOperator

topIsOr :: Rule [(SLogic, SLogic)]
topIsOr = acTopRuleFor "top-is-or" orOperator

topIsEquiv :: Rule [(SLogic, SLogic)]
topIsEquiv = acTopRuleFor "top-is-equiv" equivOperator
 where
   equivOperator = associativeOperator (:<->:) isEquiv
  
   isEquiv (p :<->: q) = Just (p, q)
   isEquiv _           = Nothing

topIsImpl :: Rule [(SLogic, SLogic)]
topIsImpl = makeSimpleRule "top-is-impl" f
 where
   f [(p :->: q, r :->: s)] = do
      guard (eqLogic p r && eqLogic q s)
      return [(p, r), (q, s)]
   f _ = Nothing
   
{- Strategie voor sterke(?) normalisatie

(prioritering)
 
1. p \/ q \/ ~p     ~> T           (propageren)
   p /\ q /\ p      ~> p /\ q
   p /\ q /\ ~p     ~> F           (propageren)

2. (p /\ q) \/ ... \/ (p /\ q /\ r)    ~> (p /\ q) \/ ...
         (subset relatie tussen rijtjes: bijzonder geval is gelijke rijtjes)
   p \/ ... \/ (~p /\ q /\ r)  ~> p \/ ... \/ (q /\ r)
         (p is hier een losse variabele)
   ~p \/ ... \/ (p /\ q /\ r)  ~> ~p \/ ... \/ (q /\ r)
         (p is hier een losse variabele)

3. a) elimineren wat aan een kant helemaal niet voorkomt (zie regel hieronder)
   b) rijtjes sorteren
   c) rijtjes aanvullen
   
Twijfelachtige regel bij stap 3: samennemen in plaats van aanvullen:
   (p /\ q /\ r) \/ ... \/ (~p /\ q /\ r)   ~> q /\ r
          (p is hier een losse variable)
-}

-- Code adapted from Common.Rewriting.AC: refactor
recAC :: [a] -> [b] -> [[([a], [b])]]
recAC [] [] = [[]]
recAC [] _  = []
recAC (a:as) bs = 
   [ (as1, bs1):ps
   | (asr, as2) <- if matchMode then [([], as)] else splits as
   , let as1 = a:asr
   , (bs1, bs2) <- splits bs
   , not (null bs1)
   , length as1==1 || length bs1==1
   , ps <- recAC as2 bs2
   ]
 where
   matchMode = False
   
splits :: [a] -> [([a], [a])]
splits = foldr insert [([], [])]
 where
   insert a ps = 
      let toLeft  (xs, ys) = (a:xs,   ys)
          toRight (xs, ys) = (  xs, a:ys)
      in map toLeft ps ++ map toRight ps