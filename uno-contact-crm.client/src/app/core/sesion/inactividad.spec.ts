import { formatoReloj, segundosRestantes } from './inactividad';

describe('Reloj de inactividad', () => {
  const MIN = 60_000;
  const base = 1_000_000;

  it('arranca en 30:00', () => {
    expect(formatoReloj(segundosRestantes(base, base))).toBe('30:00');
  });

  it('corre hacia abajo segundo a segundo', () => {
    expect(formatoReloj(segundosRestantes(base + 1000, base))).toBe('29:59');
    expect(formatoReloj(segundosRestantes(base + 29 * MIN + 59_000, base))).toBe('00:01');
  });

  it('llega a 0 a los 30 minutos sin actividad (y no baja de 0)', () => {
    expect(segundosRestantes(base + 30 * MIN, base)).toBe(0);
    expect(segundosRestantes(base + 45 * MIN, base)).toBe(0);
  });

  it('la actividad reinicia el conteo', () => {
    const actividad = base + 20 * MIN; // se movió a los 20 min
    expect(formatoReloj(segundosRestantes(base + 20 * MIN, actividad))).toBe('30:00');
    expect(segundosRestantes(base + 31 * MIN, actividad)).toBe(19 * 60); // ya no cierra al min 30
  });
});
