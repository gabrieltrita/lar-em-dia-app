export function chartWidth(element) {
  return Math.max(300, Math.round(element.clientWidth || 640));
}

export function attachTooltip(container, describe) {
  const tip = document.createElement('div');
  tip.className = 'tip';
  tip.hidden = true;
  container.append(tip);
  const show = (event) => {
    const hit = event.target.closest('[data-index]');
    if (!hit) return;
    const lines = describe(Number(hit.dataset.index));
    tip.replaceChildren(...lines.map((text, i) => {
      const line = document.createElement(i === 0 ? 'strong' : 'span');
      line.textContent = text;
      return line;
    }));
    tip.hidden = false;
    const box = container.getBoundingClientRect();
    const target = hit.getBoundingClientRect();
    const left = Math.min(Math.max(target.left + target.width / 2 - box.left, 70), box.width - 70);
    tip.style.left = `${left}px`;
  };
  container.addEventListener('pointermove', show);
  container.addEventListener('pointerdown', show);
  container.addEventListener('pointerleave', () => { tip.hidden = true; });
}
