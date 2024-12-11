// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/src/Test.sol";
import { Resolver } from "../src/resolver/Resolver.sol";
import { IResolver } from "../src/interfaces/IResolver.sol";
import { ISchemaRegistry } from "../src/interfaces/ISchemaRegistry.sol";
import { IEAS } from "../src/interfaces/IEAS.sol";

contract RegistryTest is Test {
  IEAS eas = IEAS(0xC47300428b6AD2c7D03BB76D05A176058b47E6B0);
  ISchemaRegistry schemaRegistry = ISchemaRegistry(0xD2CDF46556543316e7D34e8eDc4624e2bB95e3B6);
  IResolver resolver;

  function setUp() public {
    vm.startPrank(0x96687D2852B2b902d708819C2941d2628dBbD135);
    resolver = new Resolver(eas);
  }

  function test_registry_attest() public {
    string memory schema = "string title,string comment";
    bool revocable = false;

    bytes32 uid = schemaRegistry.register(schema, resolver, revocable);

    console2.log("Schema UID generated attest:");
    console2.logBytes32(uid);
  }

  function test_registry_response_attest() public {
    string memory schema = "bool status";
    bool revocable = true;

    bytes32 uid = schemaRegistry.register(schema, resolver, revocable);

    console2.log("Schema UID generated Response attest:");
    console2.logBytes32(uid);
  }
}
