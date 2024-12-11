// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/src/Test.sol";
import { Resolver } from "../src/resolver/Resolver.sol";
import { IResolver } from "../src/interfaces/IResolver.sol";
import { ISchemaRegistry } from "../src/interfaces/ISchemaRegistry.sol";
import { IEAS } from "../src/interfaces/IEAS.sol";
import { InvalidEAS, AccessDenied } from "../src/Common.sol";

contract ResolverTest is Test {
    IEAS eas = IEAS(0xC47300428b6AD2c7D03BB76D05A176058b47E6B0);
    ISchemaRegistry schemaRegistry = ISchemaRegistry(0xD2CDF46556543316e7D34e8eDc4624e2bB95e3B6);
    IResolver resolver;

    address deployer = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    function setUp() public {
        vm.label(deployer, "deployer");
        vm.startPrank(deployer);
        resolver = new Resolver(eas);
    }

    function test_hardcoded_badge_titles() public {
        // Get all titles
        string[] memory allTitles = resolver.getAllAttestationTitles();
        
        // Verify total number of titles
        assertEq(allTitles.length, 13, "Should have 13 hardcoded titles");

        // Expected titles array
        string[] memory expectedTitles = new string[](13);
        expectedTitles[0] = "Changed my mind";
        expectedTitles[1] = "Disagreed with somebody on stage";
        expectedTitles[2] = "Created a session on the event";
        expectedTitles[3] = "Voted on significant poll";
        expectedTitles[4] = "Early contributor";
        expectedTitles[5] = "Volunteered";
        expectedTitles[6] = "Started a new club";
        expectedTitles[7] = "Hosted a discussion";
        expectedTitles[8] = "Friend from past events";
        expectedTitles[9] = "Showed me a cool tech";
        expectedTitles[10] = "Showed me around town";
        expectedTitles[11] = "Good laughs";
        expectedTitles[12] = "Good talk";

        // Verify each title is allowed and matches expected
        for (uint i = 0; i < expectedTitles.length; i++) {
            assertTrue(
                resolver.allowedAttestationTitles(expectedTitles[i]),
                string.concat("Title should be allowed: ", expectedTitles[i])
            );
            assertTrue(
                keccak256(abi.encode(allTitles[i])) == keccak256(abi.encode(expectedTitles[i])),
                string.concat("Title mismatch at index ", vm.toString(i))
            );
        }
    }

   function test_schema_actions() public {
    bytes32[] memory uids = new bytes32[](2);

    // Test Event Attestation Schema
    string memory schema = "string title,string comment";
    bool revocable = false;
    bytes32 uid = schemaRegistry.register(schema, resolver, revocable);
    resolver.setSchema(uid, uint256(IResolver.Action.ATTEST));
    assertEq(uint(resolver.allowedSchemas(uid)), uint(IResolver.Action.ATTEST));
    uids[0] = uid;

    // Test Event Response Schema
    schema = "bool status";
    revocable = true;
    uid = schemaRegistry.register(schema, resolver, revocable);
    resolver.setSchema(uid, uint256(IResolver.Action.REPLY));
    assertEq(uint(resolver.allowedSchemas(uid)), uint(IResolver.Action.REPLY));
    uids[1] = uid;

    // Test schema revocation
    resolver.setSchema(uids[0], uint256(IResolver.Action.NONE));
    assertEq(uint(resolver.allowedSchemas(uids[0])), uint(IResolver.Action.NONE));
    
    resolver.setSchema(uids[1], uint256(IResolver.Action.NONE));
    assertEq(uint(resolver.allowedSchemas(uids[1])), uint(IResolver.Action.NONE));
  }

    function test_payable_status() public {
        assertFalse(resolver.isPayable(), "Resolver should not be payable");
    }

    function test_cannot_reply_status() public {
        bytes32 testUID = bytes32(uint256(1));
        assertFalse(resolver.cannotReply(testUID), "Should return false for new UIDs");
    }

    function test_invalid_eas() public {
        vm.expectRevert(InvalidEAS.selector);
        new Resolver(IEAS(address(0)));
    }

    function test_access_denied() public {
        vm.stopPrank();
        vm.startPrank(address(0x1));
        bytes32 schemaUID = bytes32(uint256(1));
        vm.expectRevert(AccessDenied.selector);
        resolver.setSchema(schemaUID, 1);
    }
}