// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import { IEAS, Attestation } from "../interfaces/IEAS.sol";
import { IResolver } from "../interfaces/IResolver.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { AccessDenied, InvalidEAS, InvalidLength, uncheckedInc, EMPTY_UID, NO_EXPIRATION_TIME } from "../Common.sol";

error AlreadyHasResponse();
error InsufficientValue();
error InvalidAttestationTitle();
error InvalidExpiration();
error InvalidRefUID();
error InvalidRevocability();
error InvalidRole();
error InvalidWithdraw();
error NotPayable();
error Unauthorized();

/// @author Blockful | 0xneves
/// @notice ZuVillage Resolver contract for Ethereum Attestation Service.
contract Resolver is IResolver, AccessControl {
  // The global EAS contract.
  IEAS internal immutable _eas;

   // Store deployer address
    address private immutable _deployer;

  // Maps allowed attestations (Hashed titles that can be attested)
  mapping(bytes32 => bool) private _allowedAttestationTitles; // Maybe will be removed. Titles probably will be hardcoded.

  // Maps attestation IDs to boolans (each attestation can only have one active response)
  mapping(bytes32 => bool) private _cannotReply;

  // Maps schemas ID and role ID to action
  mapping(bytes32 => Action) private _allowedSchemas;

  /// @dev Creates a new resolver.
  /// @param eas The address of the global EAS contract.
  constructor(IEAS eas) {
    if (address(eas) == address(0)) revert InvalidEAS();
    _eas = eas;
    _deployer = msg.sender; 

     // Initialize hardcoded attestation titles
    _initializeAttestationTitles();

  }

   /// @dev Initializes the allowed attestation titles with hardcoded values
    function _initializeAttestationTitles() private {
        string[13] memory titles = [
            "Changed my mind",
            "Disagreed with somebody on stage",
            "Created a session on the event",
            "Voted on significant poll",
            "Early contributor",
            "Volunteered",
            "Started a new club",
            "Hosted a discussion",
            "Friend from past events",
            "Showed me a cool tech",
            "Showed me around town",
            "Good laughs",
            "Good talk"
        ];

        for (uint i = 0; i < titles.length;) {
            _allowedAttestationTitles[keccak256(abi.encode(titles[i]))] = true;
            unchecked { i++; }
        }
    }

  /// @dev Ensures that only the EAS contract can make this call.
  modifier onlyEAS() {
    if (msg.sender != address(_eas)) revert AccessDenied();
    _;
  }

  /// @dev Ensure that only the deployer can make this call.
  modifier onlyDeployer() {
    if (msg.sender != _deployer) revert AccessDenied();
    _;
  }

  /// @inheritdoc IResolver
  function isPayable() public pure virtual returns (bool) {
    return false;
  }

  // Maybe will be removed. Titles probably will be hardcoded.
  /// @inheritdoc IResolver
  function allowedAttestationTitles(string memory title) public view returns (bool) {
    return _allowedAttestationTitles[keccak256(abi.encode(title))];
  }

  /// @inheritdoc IResolver
  function cannotReply(bytes32 uid) public view returns (bool) {
    return _cannotReply[uid];
  }

  /// @inheritdoc IResolver
  function allowedSchemas(bytes32 uid) public view returns (Action) {
    return _allowedSchemas[uid];
  }

  /// @dev Validates if the `action` is allowed for the given `role` and `schema`.
  function isActionAllowed(bytes32 uid, Action action) internal view returns (bool) {
    return _allowedSchemas[uid] == action;
  }

  /// @inheritdoc IResolver
  function attest(Attestation calldata attestation) external payable onlyEAS returns (bool) {
    // Prohibits the attestation expiration to be finite
    if (attestation.expirationTime != NO_EXPIRATION_TIME) revert InvalidExpiration();

    // Schema to create event attestations (Attestations)
    if (isActionAllowed(attestation.schema, Action.ATTEST)) {
      return attestEvent(attestation);
    }

    // Schema to create a response ( true / false )
    if (isActionAllowed(attestation.schema, Action.REPLY)) {
      return attestResponse(attestation);
    }

    return false;
  }

  /// @inheritdoc IResolver
  function revoke(Attestation calldata attestation) external payable onlyEAS returns (bool) {
    // Schema to revoke a response ( true / false )
    if (isActionAllowed(attestation.schema, Action.REPLY)) {
      _cannotReply[attestation.refUID] = false;
      return true;
    }

    return false;
  }

  /// @dev Attest an event badge.
  function attestEvent(Attestation calldata attestation) internal view returns (bool) {
    if (attestation.revocable) revert InvalidRevocability();

    // Titles for attestations must be included in this contract by the managers
    // via the {setAttestationTitle} function
    (string memory title, ) = abi.decode(attestation.data, (string, string));
    if (!_allowedAttestationTitles[keccak256(abi.encode(title))]) revert InvalidAttestationTitle();

    return true;
  }

  /// @dev Attest a response to an event badge emitted by {attestEvent}.
  function attestResponse(Attestation calldata attestation) internal returns (bool) {
    if (!attestation.revocable) revert InvalidRevocability();
    if (_cannotReply[attestation.refUID]) revert AlreadyHasResponse();

    // Checks if the attestation has a non empty reference
    if (attestation.refUID == EMPTY_UID) revert InvalidRefUID();
    Attestation memory attesterRef = _eas.getAttestation(attestation.refUID);
    // Match the attester of this attestation with the recipient of the reference attestation
    // The response is designed to be a reply to a previous attestation
    if (attesterRef.recipient != attestation.attester) revert InvalidRefUID();

    // Cannot create new responses until this attestation is revoked
    _cannotReply[attestation.refUID] = true;

    return true;
  }

  /// @inheritdoc IResolver
 function getAllAttestationTitles() public pure returns (string[] memory) {
        string[] memory titles = new string[](13);
        titles[0] = "Changed my mind";
        titles[1] = "Disagreed with somebody on stage";
        titles[2] = "Created a session on the event";
        titles[3] = "Voted on significant poll";
        titles[4] = "Early contributor";
        titles[5] = "Volunteered";
        titles[6] = "Started a new club";
        titles[7] = "Hosted a discussion";
        titles[8] = "Friend from past events";
        titles[9] = "Showed me a cool tech";
        titles[10] = "Showed me around town";
        titles[11] = "Good laughs";
        titles[12] = "Good talk";
        return titles;
    }

  /// @inheritdoc IResolver
  function setSchema(bytes32 uid, uint256 action) public onlyDeployer {
    _allowedSchemas[uid] = Action(action);
  }

  /// @dev ETH callback.
  receive() external payable virtual {
    if (!isPayable()) {
      revert NotPayable();
    }
  }
}
