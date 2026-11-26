import { Component, inject, signal } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

export interface DatosCredenciales {
  titulo: string;
  nombre: string;
  usuario: string;
  /** Si viene, se muestra directo. Si no, primero se confirma y se obtiene con `obtener`. */
  contrasena?: string;
  /** Para "Restablecer": pregunta primero y luego genera la contraseña. */
  pregunta?: string;
  obtener?: () => Promise<string>;
}

/**
 * Muestra usuario y contraseña temporal UNA sola vez, con botones Copiar.
 * No se cierra sola ni con clic afuera: solo con "Entendido", para dar tiempo de copiarlos.
 */
@Component({
  selector: 'app-credenciales-dialogo',
  imports: [MatButtonModule, MatIconModule],
  template: `
    <div class="cred">
      <div class="titulo">
        <span class="icono"><mat-icon>{{ contrasena() ? 'key' : 'help' }}</mat-icon></span>
        <h2>{{ datos.titulo }}</h2>
      </div>
      <p class="nombre">{{ datos.nombre }}</p>

      @if (!contrasena()) {
        <p class="texto">{{ datos.pregunta }}</p>
        @if (error()) {
          <p class="error" role="alert">{{ error() }}</p>
        }
        <div class="acciones">
          <button mat-button type="button" (click)="cerrar()" [disabled]="trabajando()">Cancelar</button>
          <button mat-flat-button type="button" class="principal" (click)="confirmar()" [disabled]="trabajando()">
            {{ trabajando() ? 'Generando…' : 'Restablecer' }}
          </button>
        </div>
      } @else {
        <div class="dato">
          <span class="etiqueta">Usuario</span>
          <code>{{ datos.usuario }}</code>
          <button mat-stroked-button type="button" (click)="copiar('usuario', datos.usuario)">
            <mat-icon>{{ copiado() === 'usuario' ? 'check' : 'content_copy' }}</mat-icon>
            {{ copiado() === 'usuario' ? 'Copiado' : 'Copiar' }}
          </button>
        </div>
        <div class="dato">
          <span class="etiqueta">Contraseña temporal</span>
          <code>{{ contrasena() }}</code>
          <button mat-stroked-button type="button" (click)="copiar('contrasena', contrasena()!)">
            <mat-icon>{{ copiado() === 'contrasena' ? 'check' : 'content_copy' }}</mat-icon>
            {{ copiado() === 'contrasena' ? 'Copiado' : 'Copiar' }}
          </button>
        </div>
        <p class="texto">
          Dáselos al empleado. Al entrar por primera vez deberá cambiar su contraseña.
          <strong>Esta contraseña no se volverá a mostrar.</strong>
        </p>
        <div class="acciones">
          <button mat-flat-button type="button" class="principal" (click)="cerrar()">Entendido</button>
        </div>
      }
    </div>
  `,
  styles: `
    .cred {
      border-top: 4px solid #003087;
      padding: 20px 24px 14px;
      min-width: 320px;
    }
    .titulo {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .icono {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      display: grid;
      place-items: center;
      background: #e6f5fc;
      color: #009cde;
    }
    h2 {
      margin: 0;
      font-size: 17px;
      font-weight: 700;
      color: #012169;
    }
    .nombre {
      margin: 6px 0 14px 52px;
      color: #64748b;
      font-size: 14px;
    }
    .dato {
      display: grid;
      grid-template-columns: 9.5rem 1fr auto;
      align-items: center;
      gap: 10px;
      padding: 8px 0;
      border-bottom: 1px solid #eef2f7;
    }
    .etiqueta {
      color: #64748b;
      font-size: 13px;
    }
    code {
      font-size: 17px;
      font-weight: 700;
      letter-spacing: 1px;
      color: #012169;
      user-select: all;
    }
    .texto {
      margin: 14px 0 4px;
      font-size: 13px;
      line-height: 1.5;
      color: #3c4858;
    }
    .error {
      color: #c20412;
      font-size: 13px;
    }
    .acciones {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
      margin-top: 14px;
    }
    .principal {
      background: #003087;
      color: #fff;
    }
  `,
})
export class CredencialesDialogo {
  protected readonly datos = inject<DatosCredenciales>(MAT_DIALOG_DATA);
  private readonly ref = inject(MatDialogRef<CredencialesDialogo>);

  protected readonly contrasena = signal<string | null>(this.datos.contrasena ?? null);
  protected readonly trabajando = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly copiado = signal<'usuario' | 'contrasena' | null>(null);

  protected async confirmar(): Promise<void> {
    if (!this.datos.obtener) return;
    this.trabajando.set(true);
    this.error.set(null);
    try {
      this.contrasena.set(await this.datos.obtener());
    } catch (e: unknown) {
      const titulo = (e as { error?: { title?: string } })?.error?.title;
      this.error.set(titulo ?? 'No se pudo restablecer la contraseña. Intenta de nuevo.');
    } finally {
      this.trabajando.set(false);
    }
  }

  protected async copiar(que: 'usuario' | 'contrasena', texto: string): Promise<void> {
    try {
      await navigator.clipboard.writeText(texto);
      this.copiado.set(que);
      setTimeout(() => this.copiado.set(null), 2000);
    } catch {
      /* si el navegador no deja copiar, el texto se puede seleccionar a mano */
    }
  }

  protected cerrar(): void {
    this.ref.close();
  }
}
