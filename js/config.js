/**
 * config.js
 * Direcciones de contratos desplegados en Monad Testnet y ABIs completos.
 * 
 * IMPORTANTE: Actualiza CONTRACT_ADDRESSES con las direcciones reales
 * después de desplegar los contratos con Hardhat/Foundry/Remix.
 */

// ─────────────────────────────────────────────────────────
//  Direcciones (actualizar después del deploy)
// ─────────────────────────────────────────────────────────
const CONTRACT_ADDRESSES = {
  registry:   "0x6028C6c3b9436719255f8713252bA20514fbf461",
  factory:    "0x7a4B3C2382d2a0d037F3C7a5D91cd459b78442fc",
  sbt:        "0x3F454265B1482d5d7BF3Cc5179b0B3B112600f23",
};

// Red Monad Testnet
const MONAD_CHAIN_ID     = "0x279F"; // 10143 decimal
const MONAD_CHAIN_NAME   = "Monad Testnet";
const MONAD_RPC_URL      = "https://testnet-rpc.monad.xyz";
const MONAD_EXPLORER_URL = "https://testnet.monadexplorer.com";
const MONAD_CURRENCY     = { name: "MON", symbol: "MON", decimals: 18 };

// ─────────────────────────────────────────────────────────
//  ABI: Registry
// ─────────────────────────────────────────────────────────
const REGISTRY_ABI = [
  "function registerIndividual(string _name, string _email) external",
  "function registerFoundation(string _name, string _nit, string _bankAccount, string _description, string _ipfsMetadata) external",
  "function verifyFoundation(address _foundation) external",
  "function getRole(address _user) external view returns (uint8)",
  "function isVerifiedFoundation(address _addr) external view returns (bool)",
  "function isIndividual(address _addr) external view returns (bool)",
  "function foundations(address) external view returns (string name, string nit, string bankAccount, string description, string ipfsMetadata, bool verified, uint256 registeredAt)",
  "function individuals(address) external view returns (string name, string email, uint256 registeredAt)",
  "function getFoundationList() external view returns (address[])",
  "function getFoundationCount() external view returns (uint256)",
  "event IndividualRegistered(address indexed user, string name, uint256 timestamp)",
  "event FoundationRegistered(address indexed foundation, string name, string nit, uint256 timestamp)",
  "event FoundationVerified(address indexed foundation, address indexed verifiedBy, uint256 timestamp)",
];

// ─────────────────────────────────────────────────────────
//  ABI: Factory
// ─────────────────────────────────────────────────────────
const FACTORY_ABI = [
  "function createPool(string _name, string _description, string _imageIpfs, uint256 _goalAmount, uint256 _deadline, address _beneficiary) external returns (address poolAddress)",
  "function getAllPools() external view returns (address[])",
  "function getFoundationPools() external view returns (address[])",
  "function getIndividualPools() external view returns (address[])",
  "function getPoolsByCreator(address _creator) external view returns (address[])",
  "function getTotalPoolCount() external view returns (uint256)",
  "event PoolCreated(address indexed pool, address indexed creator, uint8 poolType, string name, uint256 goalAmount, uint256 deadline, uint256 timestamp)",
];

// ─────────────────────────────────────────────────────────
//  ABI: Pool
// ─────────────────────────────────────────────────────────
const POOL_ABI = [
  "function deposit() external payable",
  "function releaseFunds() external",
  "function claimRefund() external",
  "function depositMatching() external payable",
  "function addInvite(address _invitee) external",
  "function addInviteBatch(address[] _invitees) external",
  "function cancelPool() external",
  "function name() external view returns (string)",
  "function description() external view returns (string)",
  "function imageIpfs() external view returns (string)",
  "function poolType() external view returns (uint8)",
  "function creator() external view returns (address)",
  "function beneficiary() external view returns (address)",
  "function goalAmount() external view returns (uint256)",
  "function deadline() external view returns (uint256)",
  "function totalRaised() external view returns (uint256)",
  "function matchingPool() external view returns (uint256)",
  "function matchingUsed() external view returns (uint256)",
  "function fundsReleased() external view returns (bool)",
  "function status() external view returns (uint8)",
  "function contributions(address) external view returns (uint256)",
  "function getProgress() external view returns (uint256 raised, uint256 goal, uint256 percent)",
  "function getDonorCount() external view returns (uint256)",
  "function getDonors() external view returns (address[])",
  "function getTimeLeft() external view returns (uint256)",
  "function isExpired() external view returns (bool)",
  "function isInAllowlist(address _addr) external view returns (bool)",
  "function getMatchingAvailable() external view returns (uint256)",
  "event Deposited(address indexed pool, address indexed donor, uint256 amount, uint256 totalRaised, uint256 timestamp)",
  "event FundsReleased(address indexed beneficiary, uint256 amount, uint256 timestamp)",
  "event Refunded(address indexed donor, uint256 amount, uint256 timestamp)",
  "event MatchingDeposited(address indexed sponsor, uint256 amount, uint256 timestamp)",
  "event InviteAdded(address indexed invitee, uint256 timestamp)",
  "event GoalReached(uint256 totalRaised, uint256 timestamp)",
];

// ─────────────────────────────────────────────────────────
//  ABI: SBT
// ─────────────────────────────────────────────────────────
const SBT_ABI = [
  "function balanceOf(address _owner) external view returns (uint256)",
  "function ownerOf(uint256 tokenId) external view returns (address)",
  "function tokenURI(uint256 tokenId) external view returns (string)",
  "function totalSupply() external view returns (uint256)",
  "function participationToken(address pool, address donor) external view returns (uint256)",
  "function authorizeMinter(address _minter) external",
  "function authorizeMinterByFactory(address _minter) external",
  "function authorizedMinters(address) external view returns (bool)",
  "event ParticipationMinted(address indexed donor, address indexed pool, uint256 indexed tokenId, uint256 timestamp)",
];

// ─────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────
const ROLE = { NONE: 0, INDIVIDUAL: 1, FOUNDATION: 2 };
const POOL_TYPE = { FOUNDATION: 0, INDIVIDUAL: 1 };
const POOL_STATUS = { ACTIVE: 0, GOAL_REACHED: 1, EXPIRED: 2, CANCELLED: 3 };

function shortenAddress(addr) {
  if (!addr) return "";
  return addr.slice(0, 6) + "..." + addr.slice(-4);
}

function formatMON(wei) {
  if (!wei) return "0.00";
  return parseFloat(ethers.utils.formatEther(wei)).toFixed(4);
}

function timeAgo(timestamp) {
  const diff = Date.now() / 1000 - timestamp;
  if (diff < 60)   return "hace un momento";
  if (diff < 3600) return `hace ${Math.floor(diff / 60)} min`;
  if (diff < 86400)return `hace ${Math.floor(diff / 3600)} h`;
  return `hace ${Math.floor(diff / 86400)} d`;
}

function timeLeft(deadline) {
  const diff = deadline - Math.floor(Date.now() / 1000);
  if (diff <= 0) return "Expirada";
  const d = Math.floor(diff / 86400);
  const h = Math.floor((diff % 86400) / 3600);
  const m = Math.floor((diff % 3600) / 60);
  if (d > 0)  return `${d}d ${h}h restantes`;
  if (h > 0)  return `${h}h ${m}m restantes`;
  return `${m}m restantes`;
}

async function switchToMonad() {
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: MONAD_CHAIN_ID }],
    });
  } catch (e) {
    if (e.code === 4902) {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [{
          chainId:            MONAD_CHAIN_ID,
          chainName:          MONAD_CHAIN_NAME,
          rpcUrls:            [MONAD_RPC_URL],
          nativeCurrency:     MONAD_CURRENCY,
          blockExplorerUrls:  [MONAD_EXPLORER_URL],
        }],
      });
    } else throw e;
  }
}

// Confetti animation
function launchConfetti() {
  const canvas = document.getElementById("confetti-canvas");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  canvas.width  = window.innerWidth;
  canvas.height = window.innerHeight;
  canvas.style.display = "block";

  const particles = Array.from({ length: 120 }, () => ({
    x:    Math.random() * canvas.width,
    y:    Math.random() * canvas.height - canvas.height,
    r:    Math.random() * 6 + 3,
    color: `hsl(${Math.random() * 360},80%,60%)`,
    speed: Math.random() * 3 + 2,
    angle: Math.random() * 360,
    spin:  (Math.random() - 0.5) * 0.2,
  }));

  let frame = 0;
  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    particles.forEach(p => {
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(p.angle);
      ctx.fillStyle = p.color;
      ctx.fillRect(-p.r / 2, -p.r / 2, p.r, p.r);
      ctx.restore();
      p.y     += p.speed;
      p.angle += p.spin;
      if (p.y > canvas.height) {
        p.y = -10;
        p.x = Math.random() * canvas.width;
      }
    });
    frame++;
    if (frame < 180) requestAnimationFrame(draw);
    else canvas.style.display = "none";
  }
  draw();
}
