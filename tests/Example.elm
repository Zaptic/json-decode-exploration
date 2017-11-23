module Example exposing (..)

import Expect exposing (Expectation)
import Json.Decode.Exploration as Decode exposing (..)
import Json.Decode.Exploration.Pipeline exposing (..)
import Test exposing (..)


nestedJson =
    """"
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
                            |> requiredAt [ "a", "b", "c" ] (Decode.list Decode.int)
                in
                decodeString decoder nestedJson
                    |> Expect.equal (Success [ 1, 2, 3 ])
        ]
