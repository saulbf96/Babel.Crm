/**
 * Reglas del horario de acceso (reflejan PoliticaHorario / rh.USP_VALIDA_HORARIO del servidor,
 * que es quien valida de verdad). Se usan en Alta y en Editar empleado.
 */
export const HORA_ENTRADA_DEFECTO = '08:00';
export const HORA_SALIDA_DEFECTO = '14:30';
export const TOLERANCIA_ENTRADA_MIN = 10;

/** Minutos de jornada entre "HH:mm" y "HH:mm"; si la salida es menor, cruza la medianoche. */
export function minutosJornada(entrada: string | null, salida: string | null): number | null {
  if (!/^\d{2}:\d{2}/.test(entrada ?? '') || !/^\d{2}:\d{2}/.test(salida ?? '')) return null;
  const aMin = (h: string) => Number(h.slice(0, 2)) * 60 + Number(h.slice(3, 5));
  const m = aMin(salida!) - aMin(entrada!);
  return m < 0 ? m + 1440 : m;
}

export interface EstadoHorario {
  /** Texto para mostrar debajo de las horas. */
  texto: string;
  /** false = hay un error (solo una hora, o jornada fuera de 1 a 12 h). */
  valido: boolean;
  /** true = aplica horario (las dos horas y no marcado "no aplica"). */
  aplica: boolean;
}

/** Evalúa el horario capturado (mismas reglas que el servidor). */
export function evaluarHorario(entrada: string, salida: string, noAplica: boolean): EstadoHorario {
  const hayEntrada = !!entrada;
  const haySalida = !!salida;
  if (!hayEntrada && !haySalida) {
    return { texto: 'Sin horario: puede entrar a cualquier hora.', valido: true, aplica: false };
  }
  if (hayEntrada !== haySalida) {
    return { texto: 'Captura las dos horas, o deja las dos vacías.', valido: false, aplica: false };
  }
  const m = minutosJornada(entrada, salida)!;
  const duracion = `${Math.floor(m / 60)} h${m % 60 ? ` ${m % 60} min` : ''}`;
  if (m < 60 || m > 720) {
    return { texto: `Jornada: ${duracion} · debe durar entre 1 y 12 horas.`, valido: false, aplica: false };
  }
  const nocturno = salida < entrada ? ' · termina al día siguiente' : '';
  if (noAplica) {
    return { texto: `Jornada: ${duracion}${nocturno} · puede entrar a cualquier hora.`, valido: true, aplica: false };
  }
  const [h, mi] = entrada.split(':').map(Number);
  const desde = (h * 60 + mi - TOLERANCIA_ENTRADA_MIN + 1440) % 1440;
  const desdeTxt = `${String(Math.floor(desde / 60)).padStart(2, '0')}:${String(desde % 60).padStart(2, '0')}`;
  return { texto: `Jornada: ${duracion}${nocturno} · puede entrar desde las ${desdeTxt}.`, valido: true, aplica: true };
}

/** "HH:mm" -> "HH:mm:00" para el servidor; vacío -> null. */
export function aServidor(hora: string): string | null {
  return hora ? `${hora.slice(0, 5)}:00` : null;
}
