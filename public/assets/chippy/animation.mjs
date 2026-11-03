export const STATES = Object.freeze(['idle', 'working', 'complete', 'attention']);
export const LABELS = Object.freeze({idle: 'Ready', working: 'Working', complete: 'Reply ready', attention: 'Needs attention'});
export const INTERVAL = 220;
const EDGES = [0, 314, 627, 941, 1254];
const IDLE = [0,0,0,0,0,0,0,0,1,2,0,3,0,0,0,0];
export function frameFor(state, tick) {
  if (!STATES.includes(state)) throw new RangeError('Unknown Chippy state');
  if (!Number.isSafeInteger(tick) || tick < 0) throw new RangeError('Invalid animation tick');
  const row = state === 'working' ? 1 : state === 'complete' && tick < 12 ? 2 : state === 'attention' ? 3 : 0;
  const column = row === 0 ? IDLE[tick % IDLE.length] : tick % 4;
  return {row, column, x: EDGES[column], y: EDGES[row], width: EDGES[column + 1] - EDGES[column], height: EDGES[row + 1] - EDGES[row]};
}
