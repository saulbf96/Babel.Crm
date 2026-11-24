import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { EmpleadoResumen, FiltroEmpleados } from './empleados.models';

/** Consulta de empleados contra /api/empleados (pantalla Consulta Empleados). */
@Injectable({ providedIn: 'root' })
export class EmpleadosService {
  private readonly http = inject(HttpClient);

  async consultar(filtro: FiltroEmpleados): Promise<EmpleadoResumen[]> {
    let params = new HttpParams();
    if (filtro.nombre) params = params.set('nombre', filtro.nombre);
    if (filtro.idPuesto != null) params = params.set('idPuesto', filtro.idPuesto);
    if (filtro.idCliente != null) params = params.set('idCliente', filtro.idCliente);
    params = params.set('soloActivos', String(filtro.soloActivos ?? true));

    return firstValueFrom(this.http.get<EmpleadoResumen[]>('/api/empleados', { params }));
  }
}
