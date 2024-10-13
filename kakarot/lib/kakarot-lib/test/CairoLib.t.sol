// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {CairoLib} from "src/CairoLib.sol";

contract ByteArrayConverterTest is Test {
    function testMyTokenConversion() public pure {
        bytes memory input = abi.encodePacked(
            uint256(0), // fullWordsLength
            uint256(0x000000000000000000000000000000000000000000000000004d79546f6b656e), // pendingWord
            uint256(7) // pendingWordLen
        );

        string memory result = CairoLib.byteArrayToString(input);
        assertEq(result, "MyToken", "Conversion failed for 'MyToken' input");
    }

    function testFullWord() public pure {
        bytes memory data = abi.encodePacked(
            uint256(1), // fullWordsLength
            uint256(0x48656c6c6f20576f726c642c20746869732069732061206c6f6e6765722073), // "Hello World, this is a longer s"
            uint256(0x7472696e672e), // "tring."
            uint256(6) // pendingWordLen
        );

        string memory result = CairoLib.byteArrayToString(data);
        assertEq(result, "Hello World, this is a longer string.");
    }

    function testMultipleFullWords() public pure {
        bytes memory data = abi.encodePacked(
            uint256(3),
            uint256(0x4c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e),
            uint256(0x73656374657475722061646970697363696e6720656c69742c207365642064),
            uint256(0x6f20656975736d6f642074656d706f7220696e6369646964756e7420757420),
            uint256(0x6c61626f726520657420646f6c6f7265206d61676e6120616c697175612e),
            uint256(30)
        );

        string memory result = CairoLib.byteArrayToString(data);
        assertEq(
            result,
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
        );
    }

    function testEmptyString() public pure {
        bytes memory input = abi.encodePacked(
            uint256(0), // fullWordsLength
            uint256(0), // pendingWord
            uint256(0) // pendingWordLen
        );

        string memory result = CairoLib.byteArrayToString(input);
        assertEq(result, "", "Conversion failed for empty string");
    }

    function testInvalidPendingWordLength() public {
        bytes memory input = abi.encodePacked(
            uint256(0),
            uint256(0),
            uint256(32) // Invalid pendingWordLen
        );

        vm.expectRevert("Invalid pending word length");
        CairoLib.byteArrayToString(input);
    }

    function testInvalidInputLength() public {
        bytes memory input = new bytes(95); // Too short to be valid

        vm.expectRevert("Invalid byte array length");
        CairoLib.byteArrayToString(input);
    }

    function testConcreteExample() public pure {
        // test with a concrete example returned for "MyToken"
        bytes memory input =
            hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004d79546f6b656e0000000000000000000000000000000000000000000000000000000000000007";
        string memory result = CairoLib.byteArrayToString(input);
        assertEq(result, "MyToken");
    }
}
