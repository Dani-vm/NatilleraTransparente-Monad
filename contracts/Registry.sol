// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NatilleraRegistry
 * @notice Registro on-chain de identidades: Fundaciones y Personas Naturales.
 *         Las fundaciones deben ser verificadas por el owner antes de crear pools.
 *         Las personas naturales se auto-registran sin verificación adicional.
 */
contract NatilleraRegistry {

    // ─────────────────────────────────────────────
    //  Tipos
    // ─────────────────────────────────────────────
    enum Role { NONE, INDIVIDUAL, FOUNDATION }

    struct FoundationInfo {
        string  name;
        string  nit;           // Número de identificación tributaria
        string  bankAccount;   // Cuenta bancaria destino (hash IPFS en prod)
        string  description;
        string  ipfsMetadata;  // Hash IPFS con documentos adicionales
        bool    verified;      // El owner verifica la fundación
        uint256 registeredAt;
    }

    struct IndividualInfo {
        string  name;
        string  email;         // Solo para notificaciones off-chain
        uint256 registeredAt;
    }

    // ─────────────────────────────────────────────
    //  Storage
    // ─────────────────────────────────────────────
    address public owner;

    mapping(address => Role)           public roles;
    mapping(address => FoundationInfo) public foundations;
    mapping(address => IndividualInfo) public individuals;

    address[] public foundationList;
    address[] public individualList;

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────
    event IndividualRegistered(address indexed user, string name, uint256 timestamp);
    event FoundationRegistered(address indexed foundation, string name, string nit, uint256 timestamp);
    event FoundationVerified(address indexed foundation, address indexed verifiedBy, uint256 timestamp);
    event FoundationRevoked(address indexed foundation, uint256 timestamp);

    // ─────────────────────────────────────────────
    //  Modifiers
    // ─────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Registry: Not owner");
        _;
    }

    modifier notRegistered() {
        require(roles[msg.sender] == Role.NONE, "Registry: Already registered");
        _;
    }

    // ─────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────
    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────
    //  Registration
    // ─────────────────────────────────────────────

    /**
     * @notice Registrar como persona natural.
     */
    function registerIndividual(
        string calldata _name,
        string calldata _email
    ) external notRegistered {
        require(bytes(_name).length > 0, "Registry: Name required");

        roles[msg.sender] = Role.INDIVIDUAL;
        individuals[msg.sender] = IndividualInfo({
            name: _name,
            email: _email,
            registeredAt: block.timestamp
        });
        individualList.push(msg.sender);

        emit IndividualRegistered(msg.sender, _name, block.timestamp);
    }

    /**
     * @notice Registrar como fundación. Requiere verificación posterior del owner.
     */
    function registerFoundation(
        string calldata _name,
        string calldata _nit,
        string calldata _bankAccount,
        string calldata _description,
        string calldata _ipfsMetadata
    ) external notRegistered {
        require(bytes(_name).length > 0,        "Registry: Name required");
        require(bytes(_nit).length > 0,         "Registry: NIT required");
        require(bytes(_bankAccount).length > 0, "Registry: Bank account required");

        roles[msg.sender] = Role.FOUNDATION;
        foundations[msg.sender] = FoundationInfo({
            name:         _name,
            nit:          _nit,
            bankAccount:  _bankAccount,
            description:  _description,
            ipfsMetadata: _ipfsMetadata,
            verified:     false,
            registeredAt: block.timestamp
        });
        foundationList.push(msg.sender);

        emit FoundationRegistered(msg.sender, _name, _nit, block.timestamp);
    }

    /**
     * @notice El owner verifica una fundación para que pueda crear pools públicas.
     */
    function verifyFoundation(address _foundation) external onlyOwner {
        require(roles[_foundation] == Role.FOUNDATION, "Registry: Not a foundation");
        foundations[_foundation].verified = true;
        emit FoundationVerified(_foundation, msg.sender, block.timestamp);
    }

    /**
     * @notice El owner revoca la verificación de una fundación.
     */
    function revokeFoundation(address _foundation) external onlyOwner {
        require(roles[_foundation] == Role.FOUNDATION, "Registry: Not a foundation");
        foundations[_foundation].verified = false;
        emit FoundationRevoked(_foundation, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  Views
    // ─────────────────────────────────────────────

    function getRole(address _user) external view returns (Role) {
        return roles[_user];
    }

    function isVerifiedFoundation(address _addr) external view returns (bool) {
        return roles[_addr] == Role.FOUNDATION && foundations[_addr].verified;
    }

    function isIndividual(address _addr) external view returns (bool) {
        return roles[_addr] == Role.INDIVIDUAL;
    }

    function getFoundationCount() external view returns (uint256) {
        return foundationList.length;
    }

    function getIndividualCount() external view returns (uint256) {
        return individualList.length;
    }

    function getFoundationList() external view returns (address[] memory) {
        return foundationList;
    }
}
