import { HttpErrorResponse } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { Router } from '@angular/router';
import { SesionService } from '../../core/sesion/sesion.service';

/** Inicio de sesión con usuario y contraseña de BABEL (equivale a FRM_ACCESO). */
@Component({
  selector: 'app-acceso',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatCardModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressBarModule,
  ],
  templateUrl: './acceso.html',
  styleUrl: './acceso.css',
})
export class Acceso {
  private readonly sesion = inject(SesionService);
  private readonly router = inject(Router);

  protected readonly enviando = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly verContrasena = signal(false);

  protected readonly formulario = inject(NonNullableFormBuilder).group({
    usuario: ['', [Validators.required, Validators.maxLength(50)]],
    // BABEL: la contraseña admite máximo 30 caracteres (FRM_ACCESO, TXT_CLAVE.MaxLength = 30).
    contrasena: ['', [Validators.required, Validators.maxLength(30)]],
  });

  /** El usuario se escribe en mayúsculas. */
  protected aMayusculas(): void {
    const control = this.formulario.controls.usuario;
    control.setValue(control.value.toUpperCase(), { emitEvent: false });
  }

  protected async entrar(): Promise<void> {
    if (this.formulario.invalid || this.enviando()) {
      this.formulario.markAllAsTouched();
      return;
    }

    this.enviando.set(true);
    this.error.set(null);
    const { usuario, contrasena } = this.formulario.getRawValue();
    try {
      const resultado = await this.sesion.iniciarSesion(usuario.trim(), contrasena);
      this.formulario.reset();
      // Si trae cambio de contraseña pendiente, se fuerza esa pantalla (FRM_CAMBIOPASS).
      await this.router.navigateByUrl(resultado.debeCambiarContrasena ? '/cambiar-contrasena' : '/inicio');
    } catch (e) {
      this.error.set(this.mensajeDeError(e));
      this.formulario.controls.contrasena.reset();
    } finally {
      this.enviando.set(false);
    }
  }

  private mensajeDeError(e: unknown): string {
    if (e instanceof HttpErrorResponse) {
      if (e.status === 401) return e.error?.title ?? 'Usuario y/o contraseña incorrectos.';
      if (e.status === 429) return 'Demasiados intentos. Espera un minuto y vuelve a intentar.';
    }
    return 'No hay comunicación con el servidor. Intenta de nuevo.';
  }
}
