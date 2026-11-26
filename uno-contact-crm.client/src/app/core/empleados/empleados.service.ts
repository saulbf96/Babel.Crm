import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import {
  AltaRegistrada,
  EmpleadoResumen,
  FiltroEmpleados,
  ResultadoAltaEmpleado,
  SolicitudAltaEmpleado,
  SolicitudEdicionEmpleado,
} from './empleados.models';

/** Consulta de empleados contra /api/empleados (pantalla Consulta Empleados). */
@Injectable({ providedIn: 'root' })
export class EmpleadosService {
  private readonly http = inject(HttpClient);

  async consultar(filtro: FiltroEmpleados): Promise<EmpleadoResumen[]> {
    let params = new HttpParams();
    if (filtro.nombre) params = params.set('nombre', filtro.nombre);
    if (filtro.idPuesto != null) params = params.set('idPuesto', filtro.idPuesto);
    if (filtro.idCartera != null) params = params.set('idCartera', filtro.idCartera);
    params = params.set('soloActivos', String(filtro.soloActivos ?? true));

    return firstValueFrom(this.http.get<EmpleadoResumen[]>('/api/empleados', { params }));
  }

  alta(solicitud: SolicitudAltaEmpleado): Promise<ResultadoAltaEmpleado> {
    return firstValueFrom(this.http.post<ResultadoAltaEmpleado>('/api/empleados', solicitud));
  }

  /** Da acceso a la cartera activa a un empleado que ya existe (en vez de darlo de alta otra vez). */
  darAccesoCartera(idEmpleado: number): Promise<void> {
    return firstValueFrom(this.http.post<void>(`/api/empleados/${idEmpleado}/acceso-cartera`, {}));
  }

  /** Historial de altas de la cartera de la sesión entre dos fechas (yyyy-MM-dd, inclusivo). */
  altas(desde: string, hasta: string): Promise<AltaRegistrada[]> {
    const params = new HttpParams().set('desde', desde).set('hasta', hasta);
    return firstValueFrom(this.http.get<AltaRegistrada[]>('/api/empleados/altas', { params }));
  }

  editar(idEmpleado: number, solicitud: SolicitudEdicionEmpleado): Promise<void> {
    return firstValueFrom(this.http.put<void>(`/api/empleados/${idEmpleado}`, solicitud));
  }
}
