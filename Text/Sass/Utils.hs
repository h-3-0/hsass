-- | Helper functions. This module is internal and should not be used in
-- production code.
{-# LANGUAGE CPP #-}
module Text.Sass.Utils
  (
    -- * Interoperation with C API
    withOptionalCString
  , listEntryNotNull
  , loopCList
  , copyToCList
  , newCStringUtf8
  , peekCStringUtf8
  , withCStringUtf8
    -- * Other helpers
  , concatPaths
  , arrayRange
  ) where

import           Control.Monad                    (zipWithM_, (>=>))
import           Control.Monad.IO.Class
import           Control.Monad.Loops              (whileM_)
import           Control.Monad.Trans.Class
import           Control.Monad.Trans.State.Strict
import           Data.List                        (intercalate)
import           Foreign
import           Foreign.C
import qualified GHC.Foreign                      as GHC
import qualified GHC.IO.Encoding                  as GHC
import           System.FilePath                  (searchPathSeparator)

-- Fix for transformers-0.3.0.0 (used by lts-2.17 in stack).
#if !MIN_VERSION_transformers(0,4,0)
modify' :: (Monad m) => (s -> s) -> StateT s m ()
modify' f = do
    s <- get
    put $! f s
#endif

-- | 'withOptionalCString' @str action@, if @str@ is 'Nothing', @action@ is not
-- invoked, otherwise behaves like 'withCString'.
withOptionalCString :: Maybe String -> (CString -> IO ()) -> IO ()
withOptionalCString (Just str) action = withCString str action
withOptionalCString Nothing _ = return ()

-- | Checks if the pointer in state points to non-null location.
listEntryNotNull :: (Monad m, MonadIO m) => StateT (Ptr (Ptr a)) m Bool
listEntryNotNull = do
    ptr <- get
    val <- liftIO $ peek ptr
    return $ val /= nullPtr

-- | 'loopCArray' @action list@ calls @action@ over each element of @list@ that
-- is C array with NULL signifying end of array.
loopCList :: (Monad m, MonadIO m) => (Ptr a -> m ()) -> Ptr (Ptr a) -> m ()
loopCList action list =
    flip evalStateT list $ whileM_ listEntryNotNull $ do
        ptr <- get
        val <- liftIO $ peek ptr
        modify' (`plusPtr` sizeOf val)
        lift $ action val

-- | Copies converted list of elements to new C array.
copyToCList :: (Num size, Enum size)
            => (CSize -> IO list) -- ^ List creator.
            -> (a -> IO element) -- ^ Conversion function.
            -> (list -> size -> element -> IO ()) -- ^ Set element function.
            -> [a] -- ^ Elements.
            -> IO list
copyToCList create convert set list = do
    let len = length list
    result <- create $ fromIntegral len
    zipWithM_ (addToList result) [0..fromIntegral len - 1] list
    return result
    where
        addToList lst idx = convert >=> set lst idx

-- | Marshal a Haskell string into a NUL terminated, UTF-8 encoded C string.
newCStringUtf8 :: String -> IO CString
newCStringUtf8 = GHC.newCString GHC.utf8

-- | Marshal a NUL terminated, UTF-8 encoded C string into a Haskell string.
peekCStringUtf8 :: CString -> IO String
peekCStringUtf8 = GHC.peekCString GHC.utf8

-- | Marshal a Haskell string into a NUL terminated, UTF-8 encoded C string
-- using temporary storage.
withCStringUtf8 :: String -> (CString -> IO a) -> IO a
withCStringUtf8 = GHC.withCString GHC.utf8

-- | Concatenates list of paths, separating entries with appropriate character.
concatPaths :: [FilePath] -> FilePath
concatPaths = intercalate [searchPathSeparator]

-- | Generates array indices for array of specified length.
arrayRange :: (Num a, Integral a, Enum a) => a -> [a]
arrayRange 0 = []
arrayRange l = [0..l - 1]

