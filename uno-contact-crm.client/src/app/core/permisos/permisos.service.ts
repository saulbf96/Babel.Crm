import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

/** Opción de menú que se puede dar como permiso. */
export interface OpcionPermiso {
  clave: string;
  titulo: string;
  grupo: string;
  icono: string;
}

/** Permisos actuales de un empleado (sección Permisos de Editar). */
export interface PermisosEmpleado {
  tieneUsuario: boolean;
  esRoot: boolean;
  esUstedMismo: boolean;
  puedeEditar: boolean;
  motivo: string | null;
  permisos: string[];
}

@Injectable({ providedIn: 'root' })
export class PermisosService {
  private readonly http = inject(HttpClient);
  private catalogoCache?: Promise<OpcionPermiso[]>;

  catalogo(): Promise<OpcionPermiso[]> {
    return (this.catalogoCache ??= firstValueFrom(this.http.get<OpcionPermiso[]>('/api/permisos/catalogo')));
  }

  /** Permisos que le tocan a un puesto (para marcar las casillas al elegirlo). */
  delPuesto(idPuesto: number): Promise<string[]> {
    return firstValueFrom(this.http.get<string[]>(`/api/permisos/puesto/${idPuesto}`));
  }

  deEmpleado(idEmpleado: number): Promise<PermisosEmpleado> {
    return firstValueFrom(this.http.get<PermisosEmpleado>(`/api/empleados/${idEmpleado}/permisos`));
  }
}
