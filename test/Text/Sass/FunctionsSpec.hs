module Text.Sass.FunctionsSpec where

import           Test.Hspec
import           Text.Sass  hiding (headerFunction)

fooFunction :: SassValue -> IO SassValue
fooFunction _ = return $ SassNumber 1 "px"

barFunction :: SassValue -> IO SassValue
barFunction (SassList [SassString "a"] _) = return $ SassNumber 1 "px"
barFunction _ = return $ SassError "invalid arguments"

strIdFunction :: SassValue -> IO SassValue
strIdFunction (SassList [SassString s] _) = return $ SassString s
strIdFunction _ = return $ SassError "invalid arguments"

functions :: [SassFunction]
functions =
  [ SassFunction "foo()"     fooFunction
  , SassFunction "bar($n)"   barFunction
  , SassFunction "strId($s)" strIdFunction
  ]

inclContent :: String
inclContent = "a {\n  margin: 1px; }\n"

altInclContent :: String
altInclContent = "b {\n  margin: 5px; }\n"

headerFunction :: String -> IO [SassImport]
headerFunction src = return [makeSourceImport $ src ++ "{\n  margin: 1px; }\n"]

headers :: [SassHeader]
headers = [SassHeader 1 headerFunction]

importFunction :: String -> String -> IO [SassImport]
importFunction "_imp" _ = return [makeSourceImport inclContent]
importFunction _      _ = return [makeSourceImport altInclContent]

importers :: [SassImporter]
importers = [SassImporter 1 importFunction]

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
    it "should call simple function" $ do
        let opts = def { sassFunctions = Just functions }
        compileString "a { margin: foo(); }" opts `shouldReturn`
            Right "a {\n  margin: 1px; }\n"

    it "should correctly pass arguments to function" $ do
        let opts = def { sassFunctions = Just functions }
        compileString "a { margin: bar('a'); }" opts `shouldReturn`
            Right "a {\n  margin: 1px; }\n"

    it "should correctly handle non-ASCII characters" $ do
        let opts = def { sassFunctions = Just functions }
        compileString "h1:before { content: '\9660'; }" opts `shouldReturn`
            Right "@charset \"UTF-8\";\nh1:before {\n  content: '\9660'; }\n"

    it "should correctly inject header" $ do
        let opts = def { sassHeaders = Just headers, sassInputPath = Just "path" }
        compileString "a { margin : 1px; }" opts `shouldReturn`
            Right ("path {\n  margin: 1px; }\n\na {\n  margin: 1px; }\n")

    it "should not apply header to imports" $ do
        let opts = def {
            sassHeaders = Just headers
          , sassImporters = Just importers
          , sassInputPath = Just "path"
        }
        compileString "@import '_imp';" opts `shouldReturn`
            Right ("path {\n  margin: 1px; }\n\n" ++ inclContent)

    it "should call importers" $ do
        let opts = def { sassImporters = Just importers }
        compileString "@import '_imp';" opts `shouldReturn` Right inclContent

    it "should pass import name to importers" $ do
        let opts = def { sassImporters = Just importers }
        compileString "@import 'other';" opts `shouldReturn` Right altInclContent

