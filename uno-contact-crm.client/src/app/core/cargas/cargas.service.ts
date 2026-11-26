import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { CargaAsignacion, ProcesoAsignacion, ResultadoCarga, SolicitudCarga } from './cargas.models';

/** Staging de cargas de asignaciones contra /api/cargas. */
@Injectable({ providedIn: 'root' })
export class CargasService {
  private readonly http = inject(HttpClient);

  procesos(): Promise<ProcesoAsignacion[]> {
    return firstValueFrom(this.http.get<ProcesoAsignacion[]>('/api/cargas/procesos'));
  }

  consultar(idCartera?: number): Promise<CargaAsignacion[]> {
    let params = new HttpParams();
    if (idCartera != null) params = params.set('idCartera', idCartera);
    return firstValueFrom(this.http.get<CargaAsignacion[]>('/api/cargas', { params }));
  }

  crear(solicitud: SolicitudCarga): Promise<ResultadoCarga> {
    return firstValueFrom(this.http.post<ResultadoCarga>('/api/cargas', solicitud));
  }
}
