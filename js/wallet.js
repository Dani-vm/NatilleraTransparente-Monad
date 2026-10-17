/**
 * wallet.js
 * Gestión global de la conexión wallet.
 * Expone: connectWallet(), getProvider(), getSigner(), getAddress(), getContracts()
 */

let _provider = null;
let _signer   = null;
let _address  = null;

/**
 * Conecta MetaMask, cambia a Monad y devuelve { provider, signer, address }
 */
async function connectWallet() {
  if (!window.ethereum) {
    showToast("MetaMask no está instalado. Instálalo en metamask.io", "error");
    throw new Error("No MetaMask");
  }

  const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
  _address  = accounts[0];
  _provider = new ethers.providers.Web3Provider(window.ethereum, "any");
  _signer   = _provider.getSigner();

  await switchToMonad();

  // Guardar sesión mínima
  localStorage.setItem("natillera_address", _address);

  // Escuchar cambios de cuenta
  window.ethereum.on("accountsChanged", (accs) => {
    if (accs.length === 0) {
      _address = null;
      localStorage.removeItem("natillera_address");
      window.location.reload();
    } else {
      _address = accs[0];
      localStorage.setItem("natillera_address", _address);
      window.location.reload();
    }
  });

  window.ethereum.on("chainChanged", () => window.location.reload());

  return { provider: _provider, signer: _signer, address: _address };
}

/**
 * Intenta reconectar silenciosamente si ya hay una cuenta autorizada.
 */
async function tryAutoConnect() {
  if (!window.ethereum) return null;
  try {
    const accounts = await window.ethereum.request({ method: "eth_accounts" });
    if (accounts.length > 0) {
      _address  = accounts[0];
      _provider = new ethers.providers.Web3Provider(window.ethereum, "any");
      _signer   = _provider.getSigner();
      return { provider: _provider, signer: _signer, address: _address };
    }
  } catch {}
  return null;
}

function getProvider() { return _provider; }
function getSigner()   { return _signer;   }
function getAddress()  { return _address;  }

function getContracts() {
  if (!_signer) return null;
  return {
    registry: new ethers.Contract(CONTRACT_ADDRESSES.registry, REGISTRY_ABI, _signer),
    factory:  new ethers.Contract(CONTRACT_ADDRESSES.factory,  FACTORY_ABI,  _signer),
    sbt:      new ethers.Contract(CONTRACT_ADDRESSES.sbt,      SBT_ABI,      _signer),
  };
}

function getPool(address) {
  if (!_signer) return null;
  return new ethers.Contract(address, POOL_ABI, _signer);
}

// ─────────────────────────────────────────────────────────
//  Toast Notification System
// ─────────────────────────────────────────────────────────
function showToast(message, type = "info", duration = 4000) {
  let container = document.getElementById("toast-container");
  if (!container) {
    container = document.createElement("div");
    container.id = "toast-container";
    container.className = "fixed bottom-6 right-6 z-50 flex flex-col gap-3 pointer-events-none";
    document.body.appendChild(container);
  }

  const colors = {
    info:    "bg-monad-card border-monad-accent/40 text-white",
    success: "bg-monad-card border-green-500/40 text-green-300",
    error:   "bg-monad-card border-red-500/40 text-red-300",
    warning: "bg-monad-card border-yellow-500/40 text-yellow-300",
  };

  const icons = {
    info:    "ℹ️",
    success: "✅",
    error:   "❌",
    warning: "⚠️",
  };

  const toast = document.createElement("div");
  toast.className = `pointer-events-auto max-w-sm rounded-2xl border px-4 py-3 text-sm shadow-glow
    flex items-start gap-3 translate-x-full transition-transform duration-300 ${colors[type] || colors.info}`;
  toast.innerHTML = `
    <span class="text-base mt-0.5">${icons[type] || icons.info}</span>
    <span class="flex-1 leading-snug">${message}</span>
    <button onclick="this.parentElement.remove()" class="opacity-50 hover:opacity-100 text-lg leading-none mt-0.5">×</button>
  `;

  container.appendChild(toast);
  requestAnimationFrame(() => {
    toast.style.transform = "translateX(0)";
  });

  setTimeout(() => {
    toast.style.transform = "translateX(120%)";
    setTimeout(() => toast.remove(), 300);
  }, duration);
}

// ─────────────────────────────────────────────────────────
//  Wallet UI helper
// ─────────────────────────────────────────────────────────
function updateWalletUI(address) {
  const btn    = document.getElementById("btn-connect");
  const addrEl = document.getElementById("wallet-address");
  const badge  = document.getElementById("wallet-badge");

  if (address) {
    if (btn) {
      btn.textContent = shortenAddress(address);
      btn.classList.add("connected");
    }
    if (addrEl) addrEl.textContent = shortenAddress(address);
    if (badge)  badge.classList.remove("hidden");
  } else {
    if (btn) btn.textContent = "Conectar Wallet";
    if (addrEl) addrEl.textContent = "No conectada";
    if (badge)  badge.classList.add("hidden");
  }
}

// Spinner loader — funciona con el #loader del HTML o crea uno dinámico
function showLoader(message = "Procesando en Monad...") {
  // Intentar usar el loader declarado en el HTML
  const fixed = document.getElementById("loader");
  const fixedText = document.getElementById("loader-text");
  if (fixed) {
    if (fixedText) fixedText.textContent = message;
    fixed.classList.remove("hidden");
    return;
  }

  // Fallback: crear loader dinámico
  let overlay = document.getElementById("global-loader");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "global-loader";
    overlay.className = "loader-overlay";
    overlay.innerHTML = `
      <div class="loader-inner">
        <div class="loader-spinner"></div>
        <p id="loader-msg" class="text-white/80 text-sm mt-4">${message}</p>
      </div>`;
    document.body.appendChild(overlay);
  } else {
    const msg = overlay.querySelector("#loader-msg");
    if (msg) msg.textContent = message;
  }
}

function hideLoader() {
  // Ocultar loader del HTML
  const fixed = document.getElementById("loader");
  if (fixed) { fixed.classList.add("hidden"); return; }

  // Ocultar loader dinámico
  const overlay = document.getElementById("global-loader");
  if (overlay) overlay.remove();
}

/**
 * Utilidad: formatMON — alias que usa ethers para mostrar el saldo
 * (redundante si config.js se carga antes, pero se mantiene como fallback)
 */
function formatMON(wei) {
  try {
    return parseFloat(ethers.utils.formatEther(wei)).toFixed(4) + " MON";
  } catch { return "— MON"; }
}
