// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NatilleraPool.sol";
import "./Registry.sol";
import "./ParticipationSBT.sol";

/**
 * @title NatilleraFactory
 * @notice Factory que despliega una nueva NatilleraPool por cada recaudación.
 *         - Las fundaciones verificadas crean pools públicas (FOUNDATION).
 *         - Las personas naturales crean pools privadas (INDIVIDUAL).
 *         Mantiene un registro global de todas las pools para el explorer.
 */
contract NatilleraFactory {

    // ─────────────────────────────────────────────
    //  Storage
    // ─────────────────────────────────────────────
    NatilleraRegistry  public immutable registry;
    ParticipationSBT   public immutable sbt;
    address            public immutable sbtContract;

    address[] public allPools;
    address[] public foundationPools;   // Pools públicas de fundaciones
    address[] public individualPools;   // Pools privadas de personas

    mapping(address => address[]) public poolsByCreator;

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────
    event PoolCreated(
        address indexed pool,
        address indexed creator,
        NatilleraPool.PoolType poolType,
        string name,
        uint256 goalAmount,
        uint256 deadline,
        uint256 timestamp
    );

    // ─────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────
    constructor(address _registry, address _sbtContract) {
        registry    = NatilleraRegistry(_registry);
        sbt         = ParticipationSBT(_sbtContract);
        sbtContract = _sbtContract;
    }

    // ─────────────────────────────────────────────
    //  Create Pool
    // ─────────────────────────────────────────────

    /**
     * @notice Crear una nueva pool de recaudo.
     * @param _name         Nombre de la campaña.
     * @param _description  Descripción de la campaña.
     * @param _imageIpfs    Hash IPFS de la imagen de portada.
     * @param _goalAmount   Meta en wei.
     * @param _deadline     Timestamp Unix del cierre.
     * @param _beneficiary  Dirección destino (puede ser el propio creador o la fundación).
     */
    function createPool(
        string calldata _name,
        string calldata _description,
        string calldata _imageIpfs,
        uint256         _goalAmount,
        uint256         _deadline,
        address         _beneficiary
    ) external returns (address poolAddress) {
        NatilleraRegistry.Role role = registry.getRole(msg.sender);
        require(role != NatilleraRegistry.Role.NONE, "Factory: Must be registered");

        NatilleraPool.PoolType pType;

        if (role == NatilleraRegistry.Role.FOUNDATION) {
            require(registry.isVerifiedFoundation(msg.sender), "Factory: Foundation not verified");
            pType = NatilleraPool.PoolType.FOUNDATION;
        } else {
            // INDIVIDUAL
            pType = NatilleraPool.PoolType.INDIVIDUAL;
            // Para personas naturales el beneficiario siempre es el creador mismo
            _beneficiary = msg.sender;
        }

        NatilleraPool pool = new NatilleraPool(
            NatilleraPool.PoolParams({
                poolType:    pType,
                creator:     msg.sender,
                beneficiary: _beneficiary,
                sbtContract: sbtContract,
                name:        _name,
                description: _description,
                imageIpfs:   _imageIpfs,
                goalAmount:  _goalAmount,
                deadline:    _deadline
            })
        );

        poolAddress = address(pool);
        allPools.push(poolAddress);
        poolsByCreator[msg.sender].push(poolAddress);

        if (pType == NatilleraPool.PoolType.FOUNDATION) {
            foundationPools.push(poolAddress);
        } else {
            individualPools.push(poolAddress);
        }

        // Autorizar automáticamente la pool recién creada como minter del SBT
        try sbt.authorizeMinterByFactory(poolAddress) {} catch {}

        emit PoolCreated(
            poolAddress,
            msg.sender,
            pType,
            _name,
            _goalAmount,
            _deadline,
            block.timestamp
        );
    }

    // ─────────────────────────────────────────────
    //  Views
    // ─────────────────────────────────────────────

    function getAllPools() external view returns (address[] memory) {
        return allPools;
    }

    function getFoundationPools() external view returns (address[] memory) {
        return foundationPools;
    }

    function getIndividualPools() external view returns (address[] memory) {
        return individualPools;
    }

    function getPoolsByCreator(address _creator) external view returns (address[] memory) {
        return poolsByCreator[_creator];
    }

    function getTotalPoolCount() external view returns (uint256) {
        return allPools.length;
    }
}
