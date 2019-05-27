module Hasql.Statement
(
  Statement(..),
  -- * Recipies

  -- ** Insert many
  -- $insertMany

  -- ** IN and NOT IN
  -- $inAndNotIn
)
where

import Hasql.Private.Prelude
import qualified Hasql.Decoders as Decoders
import qualified Hasql.Encoders as Encoders

{-|
Specification of a strictly single-statement query, which can be parameterized and prepared.

Consists of the following:

* SQL template,
* params encoder,
* result decoder,
* a flag, determining whether it should be prepared.

The SQL template must be formatted according to Postgres' standard,
with any non-ASCII characters of the template encoded using UTF-8.
According to the format,
parameters must be referred to using a positional notation, as in the following:
@$1@, @$2@, @$3@ and etc.
Those references must be used in accordance to the order in which the according
value encoders are specified in 'Encoders.Params'.

Following is an example of a declaration of a prepared statement with its associated codecs.

@
selectSum :: 'Statement' (Int64, Int64) Int64
selectSum = 'Statement' sql encoder decoder True where
  sql = "select ($1 + $2)"
  encoder =
    ('fst' '>$<' Encoders.'Hasql.Encoders.param' (Encoders.'Hasql.Encoders.nonNullable' Encoders.'Hasql.Encoders.int8')) '<>'
    ('snd' '>$<' Encoders.'Hasql.Encoders.param' (Encoders.'Hasql.Encoders.nullable' Encoders.'Hasql.Encoders.text'))
  decoder = Decoders.'Hasql.Decoders.singleRow' (Decoders.'Hasql.Decoders.column' (Decoders.'Hasql.Decoders.nonNullable' Decoders.'Hasql.Decoders.int8'))
@

The statement above accepts a product of two parameters of type 'Int64'
and produces a single result of type 'Int64'.
-}
data Statement a b =
  Statement ByteString (Encoders.Params a) (Decoders.Result b) Bool

instance Functor (Statement a) where
  {-# INLINE fmap #-}
  fmap = rmap

instance Profunctor Statement where
  {-# INLINE dimap #-}
  dimap f1 f2 (Statement template encoder decoder preparable) =
    Statement template (contramap f1 encoder) (fmap f2 decoder) preparable


{- $insertMany

It is not currently possible to pass in an array of encodable values
to use in an insert many statement. Instead, PostgreSQL's
(9.4 or later) @unnest@ function can be used in an analogous way
to haskell's `zip` function by passing in multiple arrays of values
to be zipped into the rows we want to insert:

@
insertMultipleLocations :: 'Statement' (Vector (UUID, Double, Double)) ()
insertMultipleLocations = 'Statement' sql encoder decoder True where
  sql = "insert into location (id, x, y) select * from unnest ($1, $2, $3)"
  encoder =
    contramap Vector.'Data.Vector.unzip3' $
    contrazip3 (vector Encoders.'Encoders.uuid') (vector Encoders.'Encoders.float8') (vector Encoders.'Encoders.float8')
    where
      vector =
        Encoders.'Encoders.param' .
        Encoders.'Encoders.nonNullable' .
        Encoders.'Encoders.array' .
        Encoders.'Encoders.dimension' 'foldl'' .
        Encoders.'Encoders.element' .
        Encoders.'Encoders.nonNullable'
  decoder = Decoders.'Decoders.noResult'
@

This approach is much more efficient than executing a single-row Insert
statement multiple times.
-}

{- $inAndNotIn

There is a common misconception that Postgresql supports array
as a parameter for the @IN@ operator.
However Postgres only supports a syntactical list of values with it,
i.e., you have to specify each option as an individual parameter
(@something IN ($1, $2, $3)@).

Clearly it would be much more convenient to provide an array as a single parameter,
but the @IN@ operator does not support that.
Fortunately, Postgres does provide such functionality with other operators:

* Use @something = ANY($1)@ instead of @something IN ($1)@
* Use @something <> ALL($1)@ instead of @something NOT IN ($1)@

For details see
<https://www.postgresql.org/docs/9.6/static/functions-comparisons.html#AEN20944 the Postgresql docs>.
-}
