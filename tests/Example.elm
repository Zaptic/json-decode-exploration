module Example exposing (..)

import Expect exposing (Expectation)
import Json.Decode.Exploration as Decode exposing (..)
import Json.Decode.Exploration.Pipeline exposing (..)
import Test exposing (..)


nestedJson =
    """
{"a": {"b": {"c": [1,2,3]}}}
"""


suite : Test
suite =
    describe "Json.Decode.Exploration.Pipeline"
        [ test "should work with requiredAt" <|
            \() ->
                let
                    decoder =
                        decode identity
                            |> optionalAt [ "a", "b", "c" ] (Decode.list Decode.int |> Decode.map Just) Nothing
                in
                decodeString decoder nestedJson
                    |> Expect.equal (Success <| Just [ 1, 2, 3 ])
        ]
