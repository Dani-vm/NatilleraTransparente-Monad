// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ParticipationSBT
 * @notice Soulbound Token (ERC-5192) que se mintea automáticamente cuando
 *         alguien dona a cualquier pool de la plataforma Natillera.
 *         Es NO transferible — prueba permanente de participación.
 */
contract ParticipationSBT {

    // ─────────────────────────────────────────────
    //  ERC-721 básico (sin transferencias)
    // ─────────────────────────────────────────────
    string public name   = "Natillera Participation Badge";
    string public symbol = "NATBADGE";

    uint256 private _tokenIdCounter;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => string)  private _tokenURIs;

    // Pool → donante → tokenId (0 = no minted)
    mapping(address => mapping(address => uint256)) public participationToken;

    // ─────────────────────────────────────────────
    //  Access control
    // ─────────────────────────────────────────────
    address public owner;
    mapping(address => bool) public authorizedMinters; // Pools autorizadas

    // ─────────────────────────────────────────────
    //  ERC-5192 Soulbound
    // ─────────────────────────────────────────────
    event Locked(uint256 tokenId);

    // ─────────────────────────────────────────────
    //  ERC-721 Events
    // ─────────────────────────────────────────────
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event ParticipationMinted(
        address indexed donor,
        address indexed pool,
        uint256 indexed tokenId,
        uint256 timestamp
    );

    // ─────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────
    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────
    //  Modifiers
    // ─────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "SBT: Not owner");
        _;
    }

    modifier onlyMinter() {
        require(
            authorizedMinters[msg.sender] || msg.sender == owner,
            "SBT: Not authorized minter"
        );
        _;
    }

    // ─────────────────────────────────────────────
    //  Admin
    // ─────────────────────────────────────────────

    function authorizeMinter(address _minter) external {
        require(
            msg.sender == owner || authorizedMinters[msg.sender],
            "SBT: Not authorized"
        );
        authorizedMinters[_minter] = true;
    }

    /**
     * @notice Permite que la Factory autorice minters directamente.
     *         La Factory debe ser registrada como authorizedMinters por el owner primero.
     */
    function authorizeMinterByFactory(address _minter) external {
        require(authorizedMinters[msg.sender], "SBT: Caller not authorized factory");
        authorizedMinters[_minter] = true;
    }

    function revokeMinter(address _minter) external onlyOwner {
        authorizedMinters[_minter] = false;
    }

    // ─────────────────────────────────────────────
    //  Mint
    // ─────────────────────────────────────────────

    /**
     * @notice Mintea un SBT para el donante. Llamado por la pool automáticamente.
     * @param _donor Dirección del donante.
     * @param _pool  Dirección de la pool donde donó.
     */
    function mint(address _donor, address _pool) external onlyMinter returns (uint256 tokenId) {
        require(_donor != address(0), "SBT: Invalid donor");
        require(_pool  != address(0), "SBT: Invalid pool");
        require(participationToken[_pool][_donor] == 0, "SBT: Already minted for this pool");

        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        _owners[tokenId]   = _donor;
        _balances[_donor] += 1;
        participationToken[_pool][_donor] = tokenId;

        // Generar metadata on-chain básica
        _tokenURIs[tokenId] = _buildMetadata(tokenId, _donor, _pool);

        emit Transfer(address(0), _donor, tokenId);
        emit Locked(tokenId);
        emit ParticipationMinted(_donor, _pool, tokenId, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  ERC-5192: Soulbound (locked = no transfer)
    // ─────────────────────────────────────────────

    function locked(uint256 /*tokenId*/) external pure returns (bool) {
        return true; // Todos los tokens son siempre locked
    }

    // ─────────────────────────────────────────────
    //  ERC-721 Views
    // ─────────────────────────────────────────────

    function balanceOf(address _owner) external view returns (uint256) {
        return _balances[_owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "SBT: Token does not exist");
        return tokenOwner;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "SBT: Token does not exist");
        return _tokenURIs[tokenId];
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    // ─────────────────────────────────────────────
    //  Transfer bloqueado (Soulbound)
    // ─────────────────────────────────────────────

    function transferFrom(address, address, uint256) external pure {
        revert("SBT: Soulbound — non-transferable");
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert("SBT: Soulbound — non-transferable");
    }

    // ─────────────────────────────────────────────
    //  Internal
    // ─────────────────────────────────────────────

    function _buildMetadata(
        uint256 _tokenId,
        address _donor,
        address _pool
    ) internal pure returns (string memory) {
        // En producción esto apuntaría a IPFS con metadata completa
        // Aquí generamos un data URI básico on-chain
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _encode(abi.encodePacked(
                '{"name":"Natillera Badge #', _uint2str(_tokenId), '",',
                '"description":"Prueba de participacion en la plataforma Natillera Web3.",',
                '"attributes":[',
                '{"trait_type":"Donor","value":"', _addr2str(_donor), '"},',
                '{"trait_type":"Pool","value":"',  _addr2str(_pool),  '"}',
                ']}'
            ))
        ));
    }

    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) { len++; j /= 10; }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) { k--; bstr[k] = bytes1(uint8(48 + _i % 10)); _i /= 10; }
        return string(bstr);
    }

    function _addr2str(address _addr) internal pure returns (string memory) {
        bytes memory data = abi.encodePacked(_addr);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0"; str[1] = "x";
        for (uint i = 0; i < 20; i++) {
            str[2 + i * 2]     = alphabet[uint(uint8(data[i] >> 4))];
            str[3 + i * 2]     = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    // Base64 encode simplificado (suficiente para metadata on-chain)
    function _encode(bytes memory data) internal pure returns (string memory) {
        bytes memory TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        bytes memory result = new bytes(encodedLen);
        uint256 i = 0;
        uint256 j = 0;
        while (i < data.length) {
            uint256 a0 = i < data.length ? uint8(data[i++]) : 0;
            uint256 a1 = i < data.length ? uint8(data[i++]) : 0;
            uint256 a2 = i < data.length ? uint8(data[i++]) : 0;
            uint256 b0 = (a0 >> 2) & 0x3F;
            uint256 b1 = ((a0 & 0x3) << 4) | ((a1 >> 4) & 0xF);
            uint256 b2 = ((a1 & 0xF) << 2) | ((a2 >> 6) & 0x3);
            uint256 b3 = a2 & 0x3F;
            result[j++] = TABLE[b0];
            result[j++] = TABLE[b1];
            result[j++] = (i > data.length + 1) ? bytes1("=") : TABLE[b2];
            result[j++] = (i > data.length)     ? bytes1("=") : TABLE[b3];
        }
        return string(result);
    }
}
