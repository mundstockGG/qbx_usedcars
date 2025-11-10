let current = null;

const market = document.getElementById("market");
const marketList = document.getElementById("marketList");
const modal = document.getElementById("listingModal");

const closeMarket = document.getElementById("closeMarket");
const closeModal = document.getElementById("closeModal");
const buyBtn = document.getElementById("buyBtn");
const cancelBtn = document.getElementById("cancelBtn"); // new (footer cancel)

const plateSpan = document.getElementById("plate");
const sellerSpan = document.getElementById("seller");
const priceSpan = document.getElementById("price");

function post(action, data) {
  fetch(`https://${GetParentResourceName()}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data || {}),
  });
}

window.addEventListener("message", (e) => {
  const d = e.data;
  if (!d || !d.action) return;

  if (d.action === "openMarket") renderMarket(d.listings || []);
  if (d.action === "openListing") openModal(d.listing);
  if (d.action === "forceClose") {
    market.classList.add("hidden");
    modal.classList.add("hidden");
    document.getElementById("overlay")?.classList.add("hidden");
  }
});

function rowHTML(l) {
  const price = Number(l.price || 0).toLocaleString();
  const seller = l.seller_name || "Seller";
  const plate = l.plate || "N/A";
  const id = l.id != null ? ` · #${l.id}` : "";
  return `
    <div class="item-icon">🚗</div>
    <div class="item-body">
      <div class="item-title">${plate} · $${price}</div>
      <div class="item-desc">Vendedor: ${seller}${id}</div>
      <div class="item-meta">
        ${
          l.km
            ? `<span class="chip">KM: ${Number(l.km).toLocaleString()}</span>`
            : ""
        }
        ${l.engine ? `<span class="chip">${l.engine}</span>` : ""}
      </div>
    </div>
    <div class="chevron">›</div>
  `;
}

function renderMarket(list) {
  marketList.innerHTML = "";
  list.forEach((l, i) => {
    const item = document.createElement("div");
    item.className = "item";
    item.setAttribute("role", "button");
    item.setAttribute("tabindex", i === 0 ? "0" : "-1");
    item.dataset.index = i;
    item.innerHTML = rowHTML(l);
    item.addEventListener("click", () => openModal(l));
    marketList.appendChild(item);
  });

  // show market, hide modal
  modal.classList.add("hidden");
  market.classList.remove("hidden");
  document.getElementById("overlay")?.classList.remove("hidden");

  // focus first item for keyboard nav
  const first = marketList.querySelector(".item");
  first?.focus();
}

// simple roving tabindex for arrow navigation (ox-like UX)
marketList?.addEventListener("keydown", (e) => {
  const items = Array.from(marketList.querySelectorAll(".item"));
  if (!items.length) return;
  const idx = items.findIndex((x) => x === document.activeElement);
  if (e.key === "ArrowDown" || e.key === "ArrowRight") {
    const next = items[(idx + 1 + items.length) % items.length];
    next.setAttribute("tabindex", "0");
    items.forEach((el) => el !== next && el.setAttribute("tabindex", "-1"));
    next.focus();
    e.preventDefault();
  } else if (e.key === "ArrowUp" || e.key === "ArrowLeft") {
    const prev = items[(idx - 1 + items.length) % items.length];
    prev.setAttribute("tabindex", "0");
    items.forEach((el) => el !== prev && el.setAttribute("tabindex", "-1"));
    prev.focus();
    e.preventDefault();
  } else if (e.key === "Enter") {
    document.activeElement?.click();
  } else if (e.key === "Escape") {
    market.classList.add("hidden");
    document.getElementById("overlay")?.classList.add("hidden");
    post("close");
  }
});

function openModal(l) {
  current = l;
  plateSpan.textContent = l.plate || "N/A";
  sellerSpan.textContent = l.seller_name || "Unknown";
  priceSpan.textContent = Number(l.price || 0).toLocaleString();

  market.classList.add("hidden");
  modal.classList.remove("hidden");
  document.getElementById("overlay")?.classList.remove("hidden");

  // autofocus cancel button like ox dialogs
  cancelBtn?.focus();
}

closeMarket.addEventListener("click", () => {
  market.classList.add("hidden");
  document.getElementById("overlay")?.classList.add("hidden");
  post("close");
});

// header close (X)
closeModal?.addEventListener("click", () => {
  modal.classList.add("hidden");
  document.getElementById("overlay")?.classList.add("hidden");
  post("close");
});

// footer cancel
cancelBtn?.addEventListener("click", () => {
  modal.classList.add("hidden");
  market.classList.remove("hidden");
  // keep overlay because another panel is open
});

// confirm buy
buyBtn.addEventListener("click", () => {
  if (current) post("buyVehicle", { id: current.id });
  modal.classList.add("hidden");
  document.getElementById("overlay")?.classList.add("hidden");
});

// ESC to close topmost
window.addEventListener("keydown", (e) => {
  if (e.key !== "Escape") return;
  if (!modal.classList.contains("hidden")) {
    modal.classList.add("hidden");
    document.getElementById("overlay")?.classList.add("hidden");
    post("close");
  } else if (!market.classList.contains("hidden")) {
    market.classList.add("hidden");
    document.getElementById("overlay")?.classList.add("hidden");
    post("close");
  }
});
