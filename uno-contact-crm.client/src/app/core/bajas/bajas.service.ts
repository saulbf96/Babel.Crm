import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

export interface CausaBaja {
  idCausaBaja: number;
  nombre: string;
}

export interface EmpleadoBaja {
  idEmpleado: number;
  nombreCompleto: string;
  usuario: string | null;
  puesto: string;
  fechaIngreso: string;
  activo: boolean;
  fechaBaja: string | null;
  causaBaja: string | null;
  comentarioBaja: string | null;
  usuarioBaja: string | null;
  fechaRegistroBaja: string | null; // cuándo se capturó la baja (con hora)
  cuentasAsignadas: number;
}

export type EstatusBaja = 'Activos' | 'Bajas' | 'Todos';

export interface SolicitudBaja {
  idCausaBaja: number;
  comentario: string;
  fechaBaja: string; // yyyy-MM-dd
}

export interface ResultadoBaja {
  cuentasAsignadas: number;
  usuariosDesactivados: number;
}

/** Bajas de personal contra /api/bajas (reemplaza FRM_BAJAPERSONAL). */
@Injectable({ providedIn: 'root' })
export class BajasService {
  private readonly http = inject(HttpClient);

  causas(): Promise<CausaBaja[]> {
    return firstValueFrom(this.http.get<CausaBaja[]>('/api/bajas/causas'));
  }

  consultar(nombre: string, estatus: EstatusBaja): Promise<EmpleadoBaja[]> {
    let params = new HttpParams().set('estatus', estatus);
    if (nombre.trim()) params = params.set('nombre', nombre.trim());
    return firstValueFrom(this.http.get<EmpleadoBaja[]>('/api/bajas', { params }));
  }

  darDeBaja(idEmpleado: number, solicitud: SolicitudBaja): Promise<ResultadoBaja> {
    return firstValueFrom(this.http.post<ResultadoBaja>(`/api/bajas/${idEmpleado}`, solicitud));
  }

  reactivar(idEmpleado: number, comentario: string): Promise<void> {
    return firstValueFrom(this.http.post<void>(`/api/bajas/${idEmpleado}/reactivar`, { comentario }));
  }
}
