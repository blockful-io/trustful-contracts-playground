// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/src/Test.sol";
import { Resolver } from "../src/resolver/Resolver.sol";
import { IResolver } from "../src/interfaces/IResolver.sol";
import { ISchemaRegistry } from "../src/interfaces/ISchemaRegistry.sol";
import { IEAS, AttestationRequest, AttestationRequestData, RevocationRequest, RevocationRequestData } from "../src/interfaces/IEAS.sol";

contract ResolverTest is Test {
    IEAS eas = IEAS(0xC47300428b6AD2c7D03BB76D05A176058b47E6B0);
    ISchemaRegistry schemaRegistry = ISchemaRegistry(0xD2CDF46556543316e7D34e8eDc4624e2bB95e3B6);
    IResolver resolver;

    address deployer = 0x92A341fdF8F844eEEB335d59aD7Ec79c33C68Ebd;
    address villager = 0xe700CCEB04d34b798B5f8b7c35E91231445Ff6C0;
    address villager2 = 0x0e949072efd935bfba099786af9d32B00AAF000F;

    function setUp() public {
        vm.label(villager, "VILLAGER");
        vm.startPrank(deployer);
        resolver = new Resolver(eas);
    }

    function test_hardcoded_titles() public {
        string[] memory titles = resolver.getAllAttestationTitles();
        assertEq(titles.length, 13);
        
        bool foundChangedMind = false;
        bool foundGoodTalk = false;
        
        for(uint i = 0; i < titles.length; i++) {
            if(keccak256(abi.encode(titles[i])) == keccak256(abi.encode("Changed my mind"))) {
                foundChangedMind = true;
            }
            if(keccak256(abi.encode(titles[i])) == keccak256(abi.encode("Good talk"))) {
                foundGoodTalk = true;
            }
        }
        
        assertTrue(foundChangedMind);
        assertTrue(foundGoodTalk);
        
        // Verify titles are allowed
        assertTrue(resolver.allowedAttestationTitles("Changed my mind"));
        assertTrue(resolver.allowedAttestationTitles("Good talk"));
    }

    function test_attestations() public {
        bytes32[] memory uids = register_allowed_schemas();
        
        // Test Event Attestation
        vm.startPrank(villager);
        bytes32 eventUID = attest_event(
            uids[0], 
            villager,
            "Changed my mind", 
            "This address changed my mind"
        );

        // Test Response
        vm.startPrank(villager);
        bytes32 responseUID = attest_response(uids[1], villager, eventUID, true);
        assertTrue(resolver.cannotReply(eventUID));
        
        // Should fail to attest response again
        assertFalse(try_attest_response(uids[1], villager, eventUID, true));
        
        // Should be able to revoke the response
        attest_response_revoke(uids[1], responseUID);
        assertFalse(resolver.cannotReply(eventUID));
        
        // Should be able to re-attest response
        attest_response(uids[1], villager, eventUID, false);
        assertTrue(resolver.cannotReply(eventUID));
    }

   function register_allowed_schemas() public returns (bytes32[] memory) {
    bytes32[] memory uids = new bytes32[](2);

    // Event Attestation SCHEMA
    string memory schema = "string title,string comment";
    bool revocable = false;
    bytes32 uid = schemaRegistry.register(schema, resolver, revocable);
    resolver.setSchema(uid, uint256(IResolver.Action.ATTEST)); 
    uids[0] = uid;

    // Event Response SCHEMA
    schema = "bool status";
    revocable = true;
    uid = schemaRegistry.register(schema, resolver, revocable);
    resolver.setSchema(uid, uint256(IResolver.Action.REPLY));   
    uids[1] = uid;

    return uids;
}

    function attest_event(
        bytes32 schemaUID,
        address recipient,
        string memory title,
        string memory comment
    ) public returns (bytes32) {
        return eas.attest(
            AttestationRequest({
                schema: schemaUID,
                data: AttestationRequestData({
                    recipient: recipient,
                    expirationTime: 0,
                    revocable: false,
                    refUID: 0,
                    data: abi.encode(title, comment),
                    value: 0
                })
            })
        );
    }

    function attest_response(
        bytes32 schemaUID,
        address recipient,
        bytes32 refUID,
        bool status
    ) public returns (bytes32) {
        return eas.attest(
            AttestationRequest({
                schema: schemaUID,
                data: AttestationRequestData({
                    recipient: recipient,
                    expirationTime: 0,
                    revocable: true,
                    refUID: refUID,
                    data: abi.encode(status),
                    value: 0
                })
            })
        );
    }

    function try_attest_response(
        bytes32 schemaUID,
        address recipient,
        bytes32 refUID,
        bool status
    ) public returns (bool) {
        try eas.attest(
            AttestationRequest({
                schema: schemaUID,
                data: AttestationRequestData({
                    recipient: recipient,
                    expirationTime: 0,
                    revocable: true,
                    refUID: refUID,
                    data: abi.encode(status),
                    value: 0
                })
            })
        ) {
            return true;
        } catch {
            return false;
        }
    }

    function attest_response_revoke(bytes32 schemaUID, bytes32 attestationUID) public {
        eas.revoke(
            RevocationRequest({
                schema: schemaUID,
                data: RevocationRequestData({ uid: attestationUID, value: 0 })
            })
        );
    }
}