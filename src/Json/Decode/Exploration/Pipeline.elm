module Json.Decode.Exploration.Pipeline
    exposing
        ( custom
        , decode
        , hardcoded
        , optional
        , optionalAt
        , required
        , requiredAt
        , resolve
        )

{-|


# Json.Decode.Pipeline

Use the `(|>)` operator to build JSON decoders.


## Decoding fields

@docs required, requiredAt, optional, optionalAt, hardcoded, custom


## Beginning and ending pipelines

@docs decode, resolve

-}

import Json.Decode.Exploration as Decode exposing (Decoder)


{-| Decode a required field.

    import Decode.Pipeline exposing (decode, required)
    import Json.Decode exposing (Decoder, int, string)

    type alias User =
        { id : Int
        , name : String
        , email : String
        }

    userDecoder : Decoder User
    userDecoder =
        decode User
            |> required "id" int
            |> required "name" string
            |> required "email" string

    result : Result String User
    result =
        Decode.decodeString
            userDecoder
            """
          {"id": 123, "email": "sam@example.com", "name": "Sam"}
        """


    -- Ok { id = 123, name = "Sam", email = "sam@example.com" }

-}
required : String -> Decoder a -> Decoder (a -> b) -> Decoder b
required key valDecoder decoder =
    decoder |> Decode.andMap (Decode.field key valDecoder)


{-| Decode a required nested field.
-}
requiredAt : List String -> Decoder a -> Decoder (a -> b) -> Decoder b
requiredAt path valDecoder decoder =
    decoder |> Decode.andMap (Decode.at path valDecoder)


{-| Decode a field that may be missing or have a null value. If the field is
missing, then it decodes as the `fallback` value. If the field is present,
then `valDecoder` is used to decode its value. If `valDecoder` fails on a
`null` value, then the `fallback` is used as if the field were missing
entirely.

    import Decode.Pipeline exposing (decode, optional, required)
    import Json.Decode exposing (Decoder, int, null, oneOf, string)

    type alias User =
        { id : Int
        , name : String
        , email : String
        }

    userDecoder : Decoder User
    userDecoder =
        decode User
            |> required "id" int
            |> optional "name" string "blah"
            |> required "email" string

    result : Result String User
    result =
        Decode.decodeString
            userDecoder
            """
          {"id": 123, "email": "sam@example.com" }
        """


    -- Ok { id = 123, name = "blah", email = "sam@example.com" }

Because `valDecoder` is given an opportunity to decode `null` values before
resorting to the `fallback`, you can distinguish between missing and `null`
values if you need to:

    userDecoder2 =
        decode User
            |> required "id" int
            |> optional "name" (oneOf [ string, null "NULL" ]) "MISSING"
            |> required "email" string

-}
optional : String -> Decoder a -> a -> Decoder (a -> b) -> Decoder b
optional key valDecoder fallback decoder =
    custom (optionalDecoder [ key ] valDecoder fallback) decoder


{-| Decode an optional nested field.
-}
optionalAt : List String -> Decoder a -> a -> Decoder (a -> b) -> Decoder b
optionalAt path valDecoder fallback decoder =
    custom (optionalDecoder path valDecoder fallback) decoder


optionalDecoder : List String -> Decoder a -> a -> Decoder a
optionalDecoder path valDecoder fallback =
    Decode.oneOf
        [ Decode.at path (Decode.null <| Decode.succeed fallback)
        , Decode.at path (Decode.succeed <| Decode.at path valDecoder)
        , Decode.succeed (Decode.succeed fallback)
        ]
        |> resolve


{-| Rather than decoding anything, use a fixed value for the next step in the
pipeline. `harcoded` does not look at the JSON at all.

    import Decode.Pipeline exposing (decode, required)
    import Json.Decode exposing (Decoder, int, string)

    type alias User =
        { id : Int
        , email : String
        , followers : Int
        }

    userDecoder : Decoder User
    userDecoder =
        decode User
            |> required "id" int
            |> required "email" string
            |> hardcoded 0

    result : Result String User
    result =
        Decode.decodeString
            userDecoder
            """
          {"id": 123, "email": "sam@example.com"}
        """


    -- Ok { id = 123, email = "sam@example.com", followers = 0 }

-}
hardcoded : a -> Decoder (a -> b) -> Decoder b
hardcoded =
    Decode.andMap << Decode.succeed


{-| Run the given decoder and feed its result into the pipeline at this point.

Consider this example.

    import Decode.Pipeline exposing (custom, decode, required)
    import Json.Decode exposing (Decoder, at, int, string)

    type alias User =
        { id : Int
        , name : String
        , email : String
        }

    userDecoder : Decoder User
    userDecoder =
        decode User
            |> required "id" int
            |> custom (at [ "profile", "name" ] string)
            |> required "email" string

    result : Result String User
    result =
        Decode.decodeString
            userDecoder
            """
          {
            "id": 123,
            "email": "sam@example.com",
            "profile": {"name": "Sam"}
          }
        """


    -- Ok { id = 123, name = "Sam", email = "sam@example.com" }

-}
custom : Decoder a -> Decoder (a -> b) -> Decoder b
custom =
    Decode.andMap


{-| Convert a `Decoder (Result x a)` into a `Decoder a`. Useful when you want
to perform some custom processing just before completing the decoding operation.

    import Decode.Pipeline exposing (decode, required, resolve)
    import Json.Decode exposing (Decoder, float, int, string)

    type alias User =
        { id : Int
        , email : String
        }

    userDecoder : Decoder User
    userDecoder =
        let
            -- toDecoder gets run *after* all the
            -- (|> required ...) steps are done.
            toDecoder : Int -> String -> Int -> Decoder User
            toDecoder id email version =
                if version > 2 then
                    succeed (User id email)
                else
                    fail "This JSON is from a deprecated source. Please upgrade!"
        in
        decode toDecoder
            |> required "id" int
            |> required "email" string
            |> required "version" int
            -- version is part of toDecoder,
            |> resolve


    -- but it is not a part of User

    result : Result String User
    result =
        Decode.decodeString
            userDecoder
            """
          {"id": 123, "email": "sam@example.com", "version": 1}
        """


    -- Err "This JSON is from a deprecated source. Please upgrade!"

-}
resolve : Decoder (Decoder a) -> Decoder a
resolve =
    Decode.andThen identity


{-| Begin a decoding pipeline. This is a synonym for [Json.Decode.succeed](http://package.elm-lang.org/packages/elm-lang/core/latest/Json-Decode#succeed),
intended to make things read more clearly.

    import Json.Decode exposing (Decoder, float, int, string)
    import Json.Decode.Pipeline exposing (decode, optional, required)

    type alias User =
        { id : Int
        , email : String
        , name : String
        }

    userDecoder : Decoder User
    userDecoder =
        decode User
            |> required "id" int
            |> required "email" string
            |> optional "name" string ""

-}
decode : a -> Decoder a
decode =
    Decode.succeed
