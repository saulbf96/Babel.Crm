import { AbstractControl, ValidationErrors } from '@angular/forms';

/**
 * Reglas de nombre y apellidos (reflejan ReglasNombre del servidor, que es quien valida de verdad):
 * solo letras (incluye Á É Í Ó Ú Ü Ñ) y espacios entre palabras; sin números ni símbolos.
 */
const SOLO_LETRAS = /^[A-ZÁÉÍÓÚÜÑ]+( [A-ZÁÉÍÓÚÜÑ]+)*$/;

/** Quita espacios sobrantes y pasa a mayúsculas (como se guarda). */
export function normalizarNombre(valor: string): string {
  return (valor ?? '').trim().replace(/\s+/g, ' ').toUpperCase();
}

/** Validador: error { letras: true } si trae números o símbolos. */
export function soloLetras(control: AbstractControl): ValidationErrors | null {
  const v = normalizarNombre(control.value ?? '');
  if (!v) return null; // lo vacío lo marca Validators.required
  return SOLO_LETRAS.test(v) ? null : { letras: true };
}

/** Ejemplos para los placeholders. */
export const EJEMPLOS_NOMBRE = {
  nombre: 'Ej. MARÍA JOSÉ',
  paterno: 'Ej. HERNÁNDEZ',
  materno: 'Ej. DE LA CRUZ',
};
