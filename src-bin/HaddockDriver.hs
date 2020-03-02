
{-
  Haddock for GHCJS
 -}

module Main where

import           Data.Foldable (foldl')
import           Control.Monad.IO.Class
import           System.Exit
import           GHC.ResponseFile (getArgsWithResponseFiles)

import           GHC
import           DynFlags
import qualified DynamicLoading

import           Documentation.Haddock
import           Haddock.Types

import qualified Compiler.GhcjsProgram  as Ghcjs
import qualified Compiler.GhcjsPlatform as Ghcjs
import qualified Compiler.Settings      as Ghcjs

  
main :: IO ()
main = getArgsWithResponseFiles >>= haddockWithGhc withGhcjs

withGhcjs :: [Flag] -> Ghc a -> IO a
withGhcjs flags action = do
  libDir <- fmap snd (getGhcDirs flags)

  -- Catches all GHC source errors, then prints and re-throws them.
  let handleSrcErrors action' = flip handleSourceError action' $ \err -> do
        printException err
        liftIO exitFailure
      ghcFlags fls = [ option | Flag_OptGhc option <- fls ]
  withGhcjs' libDir (ghcFlags flags) (\_ -> handleSrcErrors action)

-- | Start a GHC session with the -haddock flag set. Also turn off
-- compilation and linking. Then run the given 'Ghc' action.
withGhcjs' :: String -> [String] -> (DynFlags -> Ghc a) -> IO a
withGhcjs' libDir flags ghcActs = runGhc (Just libDir) $ do
  dynflags  <- getSessionDynFlags
  dynflags' <- parseGhcFlags (gopt_set dynflags Opt_Haddock) {
    hscTarget = HscNothing,
    ghcMode   = CompManager,
    ghcLink   = NoLink
    }
  let dynflags0 = dynflags' { verbosity = 2 }
  env <- liftIO Ghcjs.newGhcjsEnv
  -- We disable pattern match warnings because than can be very
  -- expensive to check
  let dynflags'' = unsetPatternMatchWarnings $
                   updOptLevel 0 $
                   Ghcjs.setGhcjsPlatform mempty env [] libDir $
                   updateWays $ addWay' (WayCustom "js") $
                   Ghcjs.setGhcjsSuffixes False $
                   gopt_unset dynflags0 Opt_SplitObjs
  -- ignore the following return-value, which is a list of packages
  -- that may need to be re-linked: Haddock doesn't do any
  -- dynamic or static linking at all!
  _ <- setSessionDynFlags dynflags''
  hscenv <- GHC.getSession
  dynflags''' <- liftIO (DynamicLoading.initializePlugins hscenv dynflags'')
  _ <- setSessionDynFlags dynflags'''
  ghcActs dynflags'''
  where

    -- ignore sublists of flags that start with "+RTS" and end in "-RTS"
    --
    -- See https://github.com/haskell/haddock/issues/666
    filterRtsFlags :: [String] -> [String]
    filterRtsFlags flgs = foldr go (const []) flgs True
      where go "-RTS" func _ = func True
            go "+RTS" func _ = func False
            go _      func False = func False
            go arg    func True = arg : func True

    parseGhcFlags :: MonadIO m => DynFlags -> m DynFlags
    parseGhcFlags dynflags = do
      -- TODO: handle warnings?

      let flags' = filterRtsFlags flags
      (dynflags', rest, _) <- parseDynamicFlags dynflags (map noLoc flags')
      if not (null rest)
        then throwE ("Couldn't parse GHC options: " ++ unwords flags')
        else return dynflags'

unsetPatternMatchWarnings :: DynFlags -> DynFlags
unsetPatternMatchWarnings dflags =
  foldl' wopt_unset dflags pattern_match_warnings
  where
    pattern_match_warnings =
      [ Opt_WarnIncompletePatterns
      , Opt_WarnIncompleteUniPatterns
      , Opt_WarnIncompletePatternsRecUpd
      , Opt_WarnOverlappingPatterns
      ]

{-
getGhcjsDirs :: [Flag] -> IO (String, String)
getGhcjsDirs flags = getGhcDirs
  case [ dir | Flag_GhcLibDir dir <- flags ] of
    [] -> error "haddock: missing -B option, cannot find library dir"
    xs -> return ("not available", last xs)
-}
