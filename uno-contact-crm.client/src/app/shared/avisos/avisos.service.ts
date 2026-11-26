import { Injectable, inject } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { AvisoDialogo, DatosAviso } from './aviso-dialogo';

/**
 * Avisos como ventana pequeña al centro de la pantalla, con los colores de UNO Contact
 * (marino/azul cielo; rojo de la marca solo para errores). Se cierran solos o con un clic.
 */
@Injectable({ providedIn: 'root' })
export class AvisosService {
  private readonly dialogo = inject(MatDialog);

  exito(mensaje: string, duracionMs = 3500, titulo = 'Listo'): void {
    this.mostrar({ tipo: 'exito', titulo, mensaje, duracionMs });
  }

  error(mensaje: string, duracionMs = 6000, titulo = 'No se pudo completar'): void {
    this.mostrar({ tipo: 'error', titulo, mensaje, duracionMs });
  }

  private mostrar(datos: DatosAviso): void {
    this.dialogo.open(AvisoDialogo, {
      data: datos,
      width: '420px',
      maxWidth: '92vw',
      autoFocus: false,
      restoreFocus: true,
      panelClass: 'aviso-ventana',
    });
  }
}
