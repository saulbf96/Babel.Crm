import { Component, OnDestroy, OnInit, inject, signal } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';

export interface DatosAviso {
  tipo: 'exito' | 'error';
  titulo: string;
  mensaje: string;
  duracionMs: number;
}

/** Ventana pequeña al centro con los colores de UNO Contact; se cierra sola (o con un clic). */
@Component({
  selector: 'app-aviso-dialogo',
  imports: [MatIconModule],
  template: `
    <div class="aviso" [class.error]="datos.tipo === 'error'" (click)="cerrar()" role="status">
      <div class="icono">
        <mat-icon>{{ datos.tipo === 'error' ? 'error' : 'check_circle' }}</mat-icon>
      </div>
      <div class="texto">
        <h2>{{ datos.titulo }}</h2>
        <p>{{ datos.mensaje }}</p>
      </div>
      <div class="barra"><span [style.animation-duration.ms]="datos.duracionMs"></span></div>
    </div>
  `,
  styles: `
    .aviso {
      position: relative;
      display: flex;
      align-items: flex-start;
      gap: 14px;
      padding: 20px 22px 22px;
      background: #ffffff;
      border-top: 4px solid #003087;
      cursor: pointer;
      min-width: 300px;
    }
    .icono {
      flex-shrink: 0;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      display: grid;
      place-items: center;
      background: #e6f5fc;
      color: #009cde;
    }
    .icono mat-icon {
      font-size: 26px;
      width: 26px;
      height: 26px;
    }
    h2 {
      margin: 2px 0 4px;
      font-size: 16px;
      font-weight: 700;
      color: #012169;
    }
    p {
      margin: 0;
      font-size: 14px;
      line-height: 1.45;
      color: #3c4858;
    }
    .error {
      border-top-color: #c20412;
    }
    .error .icono {
      background: #fce4e6;
      color: #c20412;
    }
    .error h2 {
      color: #c20412;
    }
    /* Barra que se va vaciando: cuánto falta para que se cierre sola. */
    .barra {
      position: absolute;
      left: 0;
      right: 0;
      bottom: 0;
      height: 3px;
      background: #eef2f7;
    }
    .barra span {
      display: block;
      height: 100%;
      background: #009cde;
      transform-origin: left;
      animation-name: vaciar;
      animation-timing-function: linear;
      animation-fill-mode: forwards;
    }
    .error .barra span {
      background: #c20412;
    }
    @keyframes vaciar {
      from { transform: scaleX(1); }
      to { transform: scaleX(0); }
    }
  `,
})
export class AvisoDialogo implements OnInit, OnDestroy {
  protected readonly datos = inject<DatosAviso>(MAT_DIALOG_DATA);
  private readonly ref = inject(MatDialogRef<AvisoDialogo>);
  private temporizador?: ReturnType<typeof setTimeout>;
  protected readonly visible = signal(true);

  ngOnInit(): void {
    this.temporizador = setTimeout(() => this.cerrar(), this.datos.duracionMs);
  }

  ngOnDestroy(): void {
    if (this.temporizador) clearTimeout(this.temporizador);
  }

  protected cerrar(): void {
    this.ref.close();
  }
}
