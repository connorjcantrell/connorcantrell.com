// Spatial navigation over a branching graph of screens.
// Each node has a grid coordinate (c, r) and edges to its neighbours. Swiping,
// scrolling, or pressing an arrow walks an edge; the #world plane translates so
// the active node fills the viewport. Movement is constrained to real edges, so
// the irregular branch (only `about` has a right neighbour) just works.

const NODES = {
	name:         { c: 0, r: 0, edges: { down: 'about' } },
	about:        { c: 0, r: 1, edges: { up: 'name', right: 'professional', down: 'story' } },
	professional: { c: 1, r: 1, edges: { left: 'about' } },
	story:        { c: 0, r: 2, edges: { up: 'about' } },
};

const DIRS = ['up', 'down', 'left', 'right'];

const world = document.getElementById('world');
const hints = Object.fromEntries(DIRS.map(d => [d, document.querySelector('.hint.' + d)]));

let current = NODES[location.hash.slice(1)] ? location.hash.slice(1) : 'name';
let locked = false;

// Place each screen on the plane.
for (const [id, n] of Object.entries(NODES)) {
	const el = document.querySelector(`[data-node="${id}"]`);
	if (el) { el.style.setProperty('--c', n.c); el.style.setProperty('--r', n.r); }
}

function render() {
	const n = NODES[current];
	world.style.setProperty('--col', n.c);
	world.style.setProperty('--row', n.r);
	for (const d of DIRS) hints[d].classList.toggle('on', Boolean(n.edges[d]));
	for (const dot of document.querySelectorAll('#map circle')) {
		dot.classList.toggle('active', dot.dataset.node === current);
	}
	if (location.hash.slice(1) !== current) history.replaceState(null, '', '#' + current);
}

function go(dir) {
	const next = NODES[current].edges[dir];
	if (!next || locked) return;
	current = next;
	locked = true;
	render();
	setTimeout(() => { locked = false; }, 650);
}

// Keyboard.
addEventListener('keydown', e => {
	const dir = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' }[e.key];
	if (dir) { e.preventDefault(); go(dir); }
});

// Wheel / trackpad — one screen per gesture, then a short cooldown.
let wheelLock = false;
addEventListener('wheel', e => {
	if (wheelLock) return;
	const ax = Math.abs(e.deltaX), ay = Math.abs(e.deltaY);
	if (Math.max(ax, ay) < 12) return;
	go(ay > ax ? (e.deltaY > 0 ? 'down' : 'up') : (e.deltaX > 0 ? 'right' : 'left'));
	wheelLock = true;
	setTimeout(() => { wheelLock = false; }, 700);
}, { passive: true });

// Touch swipe.
let sx = 0, sy = 0, tracking = false;
addEventListener('touchstart', e => {
	const t = e.touches[0];
	sx = t.clientX; sy = t.clientY; tracking = true;
}, { passive: true });
addEventListener('touchend', e => {
	if (!tracking) return;
	tracking = false;
	const t = e.changedTouches[0];
	const dx = t.clientX - sx, dy = t.clientY - sy;
	const ax = Math.abs(dx), ay = Math.abs(dy);
	if (Math.max(ax, ay) < 40) return;          // ignore taps and tiny drags
	go(ay > ax ? (dy < 0 ? 'down' : 'up') : (dx < 0 ? 'right' : 'left'));
}, { passive: true });

// Build the minimap straight from the graph.
(function buildMap() {
	const map = document.getElementById('map');
	const NS = 'http://www.w3.org/2000/svg';
	const ids = Object.keys(NODES);
	const cols = ids.map(i => NODES[i].c), rows = ids.map(i => NODES[i].r);
	const step = 16, pad = 8;
	const x = c => pad + (c - Math.min(...cols)) * step;
	const y = r => pad + (r - Math.min(...rows)) * step;
	const w = pad * 2 + (Math.max(...cols) - Math.min(...cols)) * step;
	const h = pad * 2 + (Math.max(...rows) - Math.min(...rows)) * step;
	map.setAttribute('viewBox', `0 0 ${w} ${h}`);
	map.setAttribute('width', w);
	map.setAttribute('height', h);

	const seen = new Set();
	for (const [id, n] of Object.entries(NODES)) {
		for (const nb of Object.values(n.edges)) {
			const key = [id, nb].sort().join('-');
			if (seen.has(key)) continue;
			seen.add(key);
			const ln = document.createElementNS(NS, 'line');
			ln.setAttribute('x1', x(n.c)); ln.setAttribute('y1', y(n.r));
			ln.setAttribute('x2', x(NODES[nb].c)); ln.setAttribute('y2', y(NODES[nb].r));
			map.appendChild(ln);
		}
	}
	for (const [id, n] of Object.entries(NODES)) {
		const dot = document.createElementNS(NS, 'circle');
		dot.setAttribute('cx', x(n.c)); dot.setAttribute('cy', y(n.r));
		dot.setAttribute('r', 3.5);
		dot.dataset.node = id;
		map.appendChild(dot);
	}
})();

render();
