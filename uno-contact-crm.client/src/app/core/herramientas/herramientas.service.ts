import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import {
  AgendaResumen,
  BlocNota,
  NegociacionResumen,
  NotaResumen,
  RecesoActivo,
  RecesoResumen,
  ResultadoOperacion,
  SolicitudActualizaDemografico,
  SolicitudAgenda,
  SolicitudNegociacion,
  SolicitudNota,
} from './herramientas.models';

/** Herramientas de gestión contra /api/herramientas. Cartera y empleado los impone la sesión. */
@Injectable({ providedIn: 'root' })
export class HerramientasService {
  private readonly http = inject(HttpClient);

  notas(idCuenta: number): Promise<NotaResumen[]> {
    return firstValueFrom(this.http.get<NotaResumen[]>(`/api/herramientas/notas/${idCuenta}`));
  }

  registrarNota(solicitud: SolicitudNota): Promise<ResultadoOperacion> {
    return firstValueFrom(
      this.http.post<ResultadoOperacion>(`/api/herramientas/notas/${solicitud.idCuenta}`, solicitud),
    );
  }

  blocNota(): Promise<BlocNota> {
    return firstValueFrom(this.http.get<BlocNota>('/api/herramientas/bloc-nota'));
  }

  guardarBlocNota(texto: string): Promise<ResultadoOperacion> {
    return firstValueFrom(
      this.http.put<ResultadoOperacion>('/api/herramientas/bloc-nota', { texto }),
    );
  }

  recesos(): Promise<RecesoResumen[]> {
    return firstValueFrom(this.http.get<RecesoResumen[]>('/api/herramientas/recesos'));
  }

  iniciarReceso(tipo: string): Promise<RecesoActivo> {
    return firstValueFrom(
      this.http.post<RecesoActivo>('/api/herramientas/recesos', { texto: tipo }),
    );
  }

  finalizarReceso(idReceso: number): Promise<ResultadoOperacion> {
    return firstValueFrom(
      this.http.post<ResultadoOperacion>(`/api/herramientas/recesos/${idReceso}/fin`, {}),
    );
  }

  agenda(idCuenta?: number): Promise<AgendaResumen[]> {
    let params = new HttpParams();
    if (idCuenta) params = params.set('idCuenta', idCuenta);
    return firstValueFrom(this.http.get<AgendaResumen[]>('/api/herramientas/agenda', { params }));
  }

  registrarAgenda(solicitud: SolicitudAgenda): Promise<ResultadoOperacion> {
    return firstValueFrom(this.http.post<ResultadoOperacion>('/api/herramientas/agenda', solicitud));
  }

  cambiarEstatusAgenda(idAgenda: number, estatus: string): Promise<ResultadoOperacion> {
    return firstValueFrom(
      this.http.post<ResultadoOperacion>(`/api/herramientas/agenda/${idAgenda}/estatus`, {
        texto: estatus,
      }),
    );
  }

  negociaciones(idCuenta: number): Promise<NegociacionResumen[]> {
    return firstValueFrom(
      this.http.get<NegociacionResumen[]>(`/api/herramientas/negociaciones/${idCuenta}`),
    );
  }

  registrarNegociacion(solicitud: SolicitudNegociacion): Promise<ResultadoOperacion> {
    return firstValueFrom(
      this.http.post<ResultadoOperacion>(
        `/api/herramientas/negociaciones/${solicitud.idCuenta}`,
        solicitud,
      ),
    );
  }

  actualizarDemografico(solicitud: SolicitudActualizaDemografico): Promise<ResultadoOperacion> {
    return firstValueFrom(
      this.http.put<ResultadoOperacion>(
        `/api/herramientas/demograficos/${solicitud.idCuenta}`,
        solicitud,
      ),
    );
  }
}
