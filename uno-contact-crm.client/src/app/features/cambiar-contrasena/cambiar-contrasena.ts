import { HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import {
  AbstractControl,
  NonNullableFormBuilder,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { Router } from '@angular/router';
import { SesionService } from '../../core/sesion/sesion.service';

/** Reflejan PoliticaContrasena del servidor (solo para los textos; el servidor es quien valida). */
const DIAS_VIGENCIA = 90;
const CONTRASENAS_RECORDADAS = 5;

/** Regla de contraseña (refleja PoliticaContrasena del servidor; el servidor la valida de nuevo). */
function reglaContrasena(control: AbstractControl): ValidationErrors | null {
  const v: string = control.value ?? '';
  const faltan: string[] = [];
  if (v.length < 8) faltan.push('8 caracteres');
  if (!/[A-ZÁÉÍÓÚÑ]/.test(v)) faltan.push('una mayúscula');
  if (!/[a-záéíóúñ]/.test(v)) faltan.push('una minúscula');
  if (!/\d/.test(v)) faltan.push('un número');
  if (!/[^\p{L}\p{N}\s]/u.test(v)) faltan.push('un carácter especial');
  return faltan.length ? { regla: faltan } : null;
}

/** Cambio de contraseña forzado (equivale a FRM_CAMBIOPASS). */
@Component({
  selector: 'app-cambiar-contrasena',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatCardModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressBarModule,
  ],
  templateUrl: './cambiar-contrasena.html',
  styleUrl: './cambiar-contrasena.css',
})
export class CambiarContrasena {
  private readonly sesion = inject(SesionService);
  private readonly router = inject(Router);

  protected readonly usuario = this.sesion.usuario;

  /** Explica por qué se pide el cambio (forzado por un admin o contraseña vencida). */
  protected readonly motivo = computed(() =>
    this.sesion.sesion()?.motivoCambioContrasena === 'Vencida'
      ? `Tu contraseña cumplió ${DIAS_VIGENCIA} días y venció. Define una nueva para continuar.`
      : `Por seguridad, ${this.usuario()} debe definir una contraseña nueva.`,
  );

  protected readonly recordadas = CONTRASENAS_RECORDADAS;
  protected readonly enviando = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly verNueva = signal(false);
  protected readonly verConfirmar = signal(false);

  protected readonly formulario = inject(NonNullableFormBuilder).group(
    {
      nueva: ['', [Validators.required, Validators.maxLength(30), reglaContrasena]],
      confirmar: ['', [Validators.required]],
    },
    { validators: (grupo) => (grupo.get('nueva')!.value === grupo.get('confirmar')!.value ? null : { noCoincide: true }) },
  );

  /** Lista de requisitos y si ya se cumplen, para mostrar checklist en vivo. */
  protected readonly requisitos = computed(() => {
    const v = this.nuevaValor();
    return [
      { texto: 'Al menos 8 caracteres', ok: v.length >= 8 },
      { texto: 'Una mayúscula', ok: /[A-ZÁÉÍÓÚÑ]/.test(v) },
      { texto: 'Una minúscula', ok: /[a-záéíóúñ]/.test(v) },
      { texto: 'Un número', ok: /\d/.test(v) },
      { texto: 'Un carácter especial (!@#$…)', ok: /[^\p{L}\p{N}\s]/u.test(v) },
    ];
  });

  private readonly nuevaValor = signal('');

  constructor() {
    this.formulario.controls.nueva.valueChanges.subscribe((v) => this.nuevaValor.set(v ?? ''));
  }

  protected async guardar(): Promise<void> {
    if (this.formulario.invalid || this.enviando()) {
      this.formulario.markAllAsTouched();
      return;
    }
    this.enviando.set(true);
    this.error.set(null);
    try {
      await this.sesion.cambiarContrasena(this.formulario.controls.nueva.value);
      await this.router.navigateByUrl('/inicio');
    } catch (e) {
      this.error.set(this.mensajeDeError(e));
    } finally {
      this.enviando.set(false);
    }
  }

  private mensajeDeError(e: unknown): string {
    if (e instanceof HttpErrorResponse && e.status === 400) {
      return e.error?.title ?? 'La contraseña no cumple la regla.';
    }
    return 'No se pudo cambiar la contraseña. Intenta de nuevo.';
  }
}
