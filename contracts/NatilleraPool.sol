// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NatilleraPool
 * @notice Pool de recaudo con dos modos:
 *   - FOUNDATION: fondos van automáticamente al beneficiario, sin reembolso.
 *   - INDIVIDUAL:  pool privada con lista blanca, permite reembolso si no se alcanza meta.
 *
 *  Funcionalidades:
 *   - Deadline on-chain con liberación / reembolso automático al expirar.
 *   - Matching fund: un sponsor puede depositar fondos que se liberan 1:1 con las donaciones.
 *   - Eventos indexables para el frontend.
 *   - Invitaciones via lista blanca (allowlist).
 */
contract NatilleraPool {

    // ─────────────────────────────────────────────
    //  Tipos
    // ─────────────────────────────────────────────
    enum PoolType   { FOUNDATION, INDIVIDUAL }
    enum PoolStatus { ACTIVE, GOAL_REACHED, EXPIRED, CANCELLED }

    // ─────────────────────────────────────────────
    //  Immutables / State
    // ─────────────────────────────────────────────
    PoolType   public immutable poolType;
    address    public immutable creator;
    address    public immutable beneficiary;   // Destino final de los fondos
    address    public immutable sbtContract;   // Contrato SBT para mint

    string     public name;
    string     public description;
    string     public imageIpfs;               // Hash IPFS de imagen de portada

    uint256    public goalAmount;              // Meta en wei
    uint256    public deadline;                // Timestamp Unix
    uint256    public totalRaised;
    uint256    public matchingPool;            // Fondos de matching disponibles
    uint256    public matchingUsed;

    bool       public fundsReleased;

    mapping(address => uint256) public contributions;  // Donante → total aportado
    mapping(address => bool)    public allowlist;      // Para pools INDIVIDUAL
    mapping(address => bool)    public hasMinted;      // Evita doble-mint de SBT

    address[]  public donors;

    PoolStatus public status;

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────
    event Deposited(
        address indexed pool,
        address indexed donor,
        uint256 amount,
        uint256 totalRaised,
        uint256 timestamp
    );
    event FundsReleased(address indexed beneficiary, uint256 amount, uint256 timestamp);
    event Refunded(address indexed donor, uint256 amount, uint256 timestamp);
    event MatchingDeposited(address indexed sponsor, uint256 amount, uint256 timestamp);
    event MatchingReleased(uint256 matchAmount, uint256 timestamp);
    event InviteAdded(address indexed invitee, uint256 timestamp);
    event PoolCancelled(uint256 timestamp);
    event GoalReached(uint256 totalRaised, uint256 timestamp);

    // ─────────────────────────────────────────────
    //  Modifiers
    // ─────────────────────────────────────────────
    modifier onlyCreator() {
        require(msg.sender == creator, "Pool: Not creator");
        _;
    }

    modifier poolActive() {
        require(status == PoolStatus.ACTIVE, "Pool: Not active");
        require(block.timestamp < deadline,  "Pool: Deadline passed");
        _;
    }

    modifier canDeposit() {
        if (poolType == PoolType.INDIVIDUAL) {
            require(allowlist[msg.sender], "Pool: Not invited");
        }
        _;
    }

    // ─────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────
    // Struct para evitar "stack too deep" en el constructor
    struct PoolParams {
        PoolType      poolType;
        address       creator;
        address       beneficiary;
        address       sbtContract;
        string        name;
        string        description;
        string        imageIpfs;
        uint256       goalAmount;
        uint256       deadline;
    }

    constructor(PoolParams memory p) {
        require(p.goalAmount > 0,             "Pool: Goal must be > 0");
        require(p.deadline > block.timestamp, "Pool: Deadline must be in future");
        require(p.beneficiary != address(0),  "Pool: Invalid beneficiary");

        poolType    = p.poolType;
        creator     = p.creator;
        beneficiary = p.beneficiary;
        sbtContract = p.sbtContract;
        name        = p.name;
        description = p.description;
        imageIpfs   = p.imageIpfs;
        goalAmount  = p.goalAmount;
        deadline    = p.deadline;
        status      = PoolStatus.ACTIVE;

        // El creador siempre está en la allowlist
        allowlist[p.creator] = true;
    }

    // ─────────────────────────────────────────────
    //  Core: Depositar
    // ─────────────────────────────────────────────

    /**
     * @notice Aportar fondos a la pool.
     *         - Para FOUNDATION: el dinero va al beneficiario automáticamente.
     *         - Para INDIVIDUAL: el dinero queda en escrow hasta el deadline.
     */
    function deposit() external payable poolActive canDeposit {
        require(msg.value > 0, "Pool: Amount must be > 0");

        if (contributions[msg.sender] == 0) {
            donors.push(msg.sender);
        }
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Deposited(address(this), msg.sender, msg.value, totalRaised, block.timestamp);

        // Intentar mint de SBT (no falla si el contrato SBT falla)
        _tryMintSBT(msg.sender);

        // Aplicar matching si hay fondos disponibles
        uint256 matchAvailable = matchingPool - matchingUsed;
        if (matchAvailable > 0) {
            uint256 matchAmount = msg.value < matchAvailable ? msg.value : matchAvailable;
            matchingUsed += matchAmount;
            totalRaised  += matchAmount;
            emit MatchingReleased(matchAmount, block.timestamp);
        }

        if (totalRaised >= goalAmount) {
            status = PoolStatus.GOAL_REACHED;
            emit GoalReached(totalRaised, block.timestamp);
        }

        // FOUNDATION: transferencia automática inmediata
        if (poolType == PoolType.FOUNDATION) {
            uint256 toSend = address(this).balance;
            if (toSend > 0) {
                (bool ok, ) = payable(beneficiary).call{value: toSend}("");
                require(ok, "Pool: Transfer failed");
                fundsReleased = true;
                emit FundsReleased(beneficiary, toSend, block.timestamp);
            }
        }
    }

    // ─────────────────────────────────────────────
    //  Liberación de fondos (INDIVIDUAL)
    // ─────────────────────────────────────────────

    /**
     * @notice Liberar fondos al beneficiario (solo si se alcanzó la meta o el creador lo activa).
     *         Solo aplica para pools INDIVIDUAL.
     */
    function releaseFunds() external onlyCreator {
        require(poolType == PoolType.INDIVIDUAL,            "Pool: Use auto-release for foundations");
        require(!fundsReleased,                             "Pool: Already released");
        require(
            status == PoolStatus.GOAL_REACHED ||
            block.timestamp >= deadline,
            "Pool: Not releasable yet"
        );

        fundsReleased = true;
        uint256 balance = address(this).balance;
        require(balance > 0, "Pool: Nothing to release");

        (bool ok, ) = payable(beneficiary).call{value: balance}("");
        require(ok, "Pool: Transfer failed");

        emit FundsReleased(beneficiary, balance, block.timestamp);
    }

    /**
     * @notice Reclamar reembolso si la pool expiró sin alcanzar la meta (solo INDIVIDUAL).
     */
    function claimRefund() external {
        require(poolType == PoolType.INDIVIDUAL, "Pool: Foundations do not refund");
        require(block.timestamp >= deadline,     "Pool: Not expired yet");
        require(status != PoolStatus.GOAL_REACHED || !fundsReleased, "Pool: Goal was reached");
        require(!fundsReleased,                  "Pool: Funds already released");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "Pool: Nothing to refund");

        contributions[msg.sender] = 0;
        totalRaised -= amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Pool: Refund failed");

        emit Refunded(msg.sender, amount, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  Matching Fund
    // ─────────────────────────────────────────────

    /**
     * @notice Un sponsor deposita fondos de matching.
     */
    function depositMatching() external payable {
        require(msg.value > 0,                  "Pool: Matching must be > 0");
        require(status == PoolStatus.ACTIVE,    "Pool: Not active");
        require(block.timestamp < deadline,     "Pool: Deadline passed");

        matchingPool += msg.value;
        emit MatchingDeposited(msg.sender, msg.value, block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  Invitaciones (INDIVIDUAL)
    // ─────────────────────────────────────────────

    /**
     * @notice Agregar dirección a la lista blanca (solo creador, solo pools INDIVIDUAL).
     */
    function addInvite(address _invitee) external onlyCreator {
        require(poolType == PoolType.INDIVIDUAL, "Pool: Only for individual pools");
        require(_invitee != address(0),          "Pool: Invalid address");
        allowlist[_invitee] = true;
        emit InviteAdded(_invitee, block.timestamp);
    }

    /**
     * @notice Agregar múltiples invitaciones de una vez.
     */
    function addInviteBatch(address[] calldata _invitees) external onlyCreator {
        require(poolType == PoolType.INDIVIDUAL, "Pool: Only for individual pools");
        for (uint i = 0; i < _invitees.length; i++) {
            if (_invitees[i] != address(0)) {
                allowlist[_invitees[i]] = true;
                emit InviteAdded(_invitees[i], block.timestamp);
            }
        }
    }

    /**
     * @notice Cancelar la pool (solo creador, solo si no se liberaron fondos).
     */
    function cancelPool() external onlyCreator {
        require(!fundsReleased, "Pool: Already released");
        status = PoolStatus.CANCELLED;
        emit PoolCancelled(block.timestamp);
    }

    // ─────────────────────────────────────────────
    //  Views
    // ─────────────────────────────────────────────

    function getProgress() external view returns (uint256 raised, uint256 goal, uint256 percent) {
        raised  = totalRaised;
        goal    = goalAmount;
        percent = goalAmount > 0 ? (totalRaised * 100) / goalAmount : 0;
        if (percent > 100) percent = 100;
    }

    function getDonorCount() external view returns (uint256) {
        return donors.length;
    }

    function getDonors() external view returns (address[] memory) {
        return donors;
    }

    function getTimeLeft() external view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    function isExpired() external view returns (bool) {
        return block.timestamp >= deadline;
    }

    function isInAllowlist(address _addr) external view returns (bool) {
        return allowlist[_addr];
    }

    function getMatchingAvailable() external view returns (uint256) {
        return matchingPool - matchingUsed;
    }

    // ─────────────────────────────────────────────
    //  Internal
    // ─────────────────────────────────────────────

    function _tryMintSBT(address _donor) internal {
        if (sbtContract == address(0)) return;
        if (hasMinted[_donor]) return;

        hasMinted[_donor] = true;

        // Llamada low-level para no revertir si SBT falla
        bytes memory data = abi.encodeWithSignature("mint(address,address)", _donor, address(this));
        (bool ok, ) = sbtContract.call(data);
        // Silenciamos el error intencionalmente
        if (!ok) {
            hasMinted[_donor] = false; // Permitir reintento
        }
    }

    receive() external payable {
        // Recibir fondos sin datos (por si acaso)
    }
}
