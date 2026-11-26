import { Component, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTableModule } from '@angular/material/table';
import { SesionService } from '../../core/sesion/sesion.service';
import { UsuarioAdmin } from '../../core/usuarios/usuarios.models';
import { UsuariosService } from '../../core/usuarios/usuarios.service';

/** Administración de usuarios del Administrador (desbloquear / forzar cambio), por campaña. */
@Component({
  selector: 'app-usuarios',
  imports: [
    MatButtonModule,
    MatCheckboxModule,
    MatIconModule,
    MatProgressBarModule,
    MatTableModule,
  ],
  templateUrl: './usuarios.html',
  styleUrl: './usuarios.css',
})
export class Usuarios {
  private readonly servicio = inject(UsuariosService);
  private readonly sesion = inject(SesionService);
  private readonly avisos = inject(MatSnackBar);

  protected readonly cartera = this.sesion.cartera;
  protected readonly cargando = signal(false);
  protected readonly soloBloqueados = signal(false);
  protected readonly usuarios = signal<UsuarioAdmin[]>([]);
  protected readonly columnas = ['usuario', 'empleado', 'puesto', 'estatus', 'acciones'];

  constructor() {
    this.cargar();
  }

  protected async cargar(): Promise<void> {
    this.cargando.set(true);
    try {
      this.usuarios.set(await this.servicio.consultar(this.soloBloqueados()));
    } catch {
      this.avisos.open('No se pudieron cargar los usuarios.', 'Cerrar', { duration: 4000 });
    } finally {
      this.cargando.set(false);
    }
  }

  /**
   * Un solo estatus por usuario, el que manda: Inactivo (baja) > Bloqueado > Cambio pendiente > Activo.
   * Un usuario inactivo no puede entrar, así que estar bloqueado o con cambio pendiente no importa.
   */
  protected estatus(u: UsuarioAdmin): { texto: string; clase: string } {
    if (!u.activo) return { texto: 'Inactivo', clase: 'chip no' };
    if (u.bloqueado) return { texto: 'Bloqueado', clase: 'chip alerta' };
    if (u.debeCambiarContrasena) return { texto: 'Cambio pendiente', clase: 'chip aviso' };
    return { texto: 'Activo', clase: 'chip ok' };
  }

  protected alternarSoloBloqueados(valor: boolean): void {
    this.soloBloqueados.set(valor);
    this.cargar();
  }

  protected desbloquear(u: UsuarioAdmin): Promise<void> {
    return this.accion(() => this.servicio.desbloquear(u.idUsuario), `${u.usuario} desbloqueado.`);
  }

  protected forzarCambio(u: UsuarioAdmin): Promise<void> {
    return this.accion(() => this.servicio.forzarCambio(u.idUsuario), `${u.usuario} deberá cambiar su contraseña al entrar.`);
  }

  protected bloquear(u: UsuarioAdmin): Promise<void> {
    return this.accion(() => this.servicio.bloquear(u.idUsuario), `${u.usuario} bloqueado.`);
  }

  private async accion(fn: () => Promise<void>, exito: string): Promise<void> {
    try {
      await fn();
      this.avisos.open(exito, 'Cerrar', { duration: 3000 });
      await this.cargar();
    } catch {
      this.avisos.open('No se pudo completar la acción.', 'Cerrar', { duration: 4000 });
    }
  }
}
