// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {MerkleTree, IHasher} from "./MerkleTree.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";



interface IVerifier_deposit {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[5] calldata _pubSignals
    ) external returns (bool);
}

interface IVerifier_withdraw {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[41] calldata _pubSignals
    ) external returns (bool);
}

contract zkRingSig is MerkleTree, ReentrancyGuard {
    IVerifier_deposit public immutable verifier_deposit;
    IVerifier_withdraw public immutable verifier_withdraw;
    uint256 public denomination;
    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => bool) public nullilfierHashes;

    bytes32[] public commitmentsList;

    bytes32[2] public supervisorPublickeyStart = [bytes32(0x1a6ef912793139a54cbbe77ceff5acce3140b659744d1c516aad7682ba979199), bytes32(0x198f3a926b833efd0056926724c072fdcfb1ebb84e77e60daa14a1484070dd07)];
    bytes32[2] public supervisorPublickeyEnd = [bytes32(0x1f76b93712e7dcb087468c1469e1f8425d17d265d2f870c9c22d9cb1399e5986), bytes32(0x2f7843eb4df4334d2f14a3a844c4430bee0ec46cfec755fcf02707f3a424f5fa)];
    
    mapping(bytes32 => mapping(bytes32 => address)) public depositorOfkS;
    mapping(bytes32 => mapping(bytes32 => address)) public withdrawerOfkE;

    event Deposit(bytes32 commitment, uint32 leafIndex);
    event Withdraw(address _recipient, bytes32 _nullilfierHash);

    constructor(
        IHasher _hasher,
        IVerifier_deposit _verifier_deposit,
        IVerifier_withdraw _verifier_withdraw,
        uint256 _denomination,
        uint32 _merkleTreeHeight
    ) MerkleTree(_merkleTreeHeight, _hasher) {
        verifier_deposit = _verifier_deposit;
        verifier_withdraw = _verifier_withdraw;
        denomination = _denomination;
    }

    function deposit(
        bytes calldata _proof, 
        bytes32 kG_Hash,
        bytes32[2] calldata kS,
        bytes32[2] calldata S
        ) external payable nonReentrant {

        require(S[0] == supervisorPublickeyStart[0] && S[1] == supervisorPublickeyStart[1],  "S invalid");


        uint256[8] memory p = abi.decode(_proof, (uint256[8]));

        require(
            verifier_deposit.verifyProof(
                [p[0], p[1]],
                [[p[2], p[3]], [p[4], p[5]]],
                [p[6], p[7]],
                [uint256(kG_Hash), uint256(kS[0]), uint256(kS[1]), uint256(S[0]), uint256(S[1])]
            ),
            "Invalid depost proof"
        );
        
        require(!commitments[kG_Hash], "The kG_Hash has been added");
        require(msg.value == denomination, "Error denomination");

        depositorOfkS[kS[0]][kS[1]] = msg.sender;

        uint32 leafIndex = insert(kG_Hash); // 2^20
        commitments[kG_Hash] = true;
        commitmentsList.push(kG_Hash);  // 
        emit Deposit(kG_Hash, leafIndex);
    }

    function withdraw(
        bytes calldata _proof,
        uint[41] calldata _pubSignals
    ) external nonReentrant {

        bytes32 kH_Hash = bytes32(_pubSignals[0]);
        bytes32[2] memory kE = [bytes32(_pubSignals[1]), bytes32(_pubSignals[2])];
        bytes32[] memory rootList = new bytes32[](32);
        for(uint i=0; i<32; i++){
            rootList[i] = bytes32(_pubSignals[i+3]);
        }
        bytes32[2] memory E = [bytes32(_pubSignals[35]), bytes32(_pubSignals[36])];
        address recipient = address(uint160(_pubSignals[37]));
        address relayer = address(uint160(_pubSignals[38]));
        uint fee = _pubSignals[39];
        uint refund = _pubSignals[40];


        require(E[0] == supervisorPublickeyEnd[0] && E[1] == supervisorPublickeyEnd[1],  "E invalid");

        require(
            !nullilfierHashes[kH_Hash],
            "The kH_Hash has already been spent"
        );

        // to be do later...
        // // check root exists in merkle tree
        // require(isKnownRoot(_root), "Root not exists");


        uint256[8] memory p = abi.decode(_proof, (uint256[8]));

        require(
            verifier_withdraw.verifyProof(
                [p[0], p[1]],
                [[p[2], p[3]], [p[4], p[5]]],
                [p[6], p[7]],
                _pubSignals
            ),
            "Invalid withdraw proof"
        );
        nullilfierHashes[kH_Hash] = true;
        withdrawerOfkE[kE[0]][kE[1]] = recipient;
        // // send ETH to _recipient
        (bool success, ) = payable(recipient).call{value: denomination}("");
        // require(success, "pay failed");
        emit Withdraw(recipient, kH_Hash);
    }

    // for test only
    function getCommitments() public view returns(bytes32[] memory){
        uint _num = commitmentsList.length;
        bytes32[] memory _list = new bytes32[](_num);
        for(uint i=0; i<_num; i++){
            _list[i] = commitmentsList[i];
        }
        return _list;
    }
}
