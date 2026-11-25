import { Routes } from '@angular/router';
import { perfilGuard, sesionGuard } from './core/sesion/perfil.guard';
import { Acceso } from './features/acceso/acceso';
import { AccesoDenegado } from './features/acceso-denegado/acceso-denegado';
import { Inicio } from './features/inicio/inicio';
import { Shell } from './layout/shell';
import { EnConstruccion } from './shared/en-construccion/en-construccion';

export const routes: Routes = [
  { path: 'acceso', component: Acceso, title: 'Iniciar sesión · UNO Contact CRM' },
  {
    path: '',
    component: Shell,
    canActivate: [sesionGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'inicio' },
      { path: 'inicio', component: Inicio, title: 'Inicio · UNO Contact CRM' },
      {
        path: 'asesor',
        canMatch: [perfilGuard('Asesor')],
        component: EnConstruccion,
        data: { titulo: 'Gestión de cartera' },
        title: 'Gestión de cartera · UNO Contact CRM',
      },
      {
        path: 'supervision',
        canMatch: [perfilGuard('Supervisor')],
        component: EnConstruccion,
        data: { titulo: 'Supervisión' },
        title: 'Supervisión · UNO Contact CRM',
      },
      {
        path: 'administracion',
        pathMatch: 'full',
        redirectTo: 'administracion/empleados',
      },
      {
        path: 'administracion/empleados',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/empleados/empleados').then((m) => m.Empleados),
        title: 'Consulta de empleados · UNO Contact CRM',
      },
      {
        path: 'administracion/alta-empleados',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/alta-empleados/alta-empleados').then((m) => m.AltaEmpleados),
        title: 'Alta de empleados · UNO Contact CRM',
      },
      {
        path: 'administracion/asignar-personal',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/asignar-personal/asignar-personal').then((m) => m.AsignarPersonal),
        title: 'Asignar personal · UNO Contact CRM',
      },
      {
        path: 'administracion/cambiar-cartera',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/cambiar-cartera/cambiar-cartera').then((m) => m.CambiarCartera),
        title: 'Cambia cartera · UNO Contact CRM',
      },
      {
        path: 'administracion/carga-asignaciones',
        canMatch: [perfilGuard('Administrador')],
        loadComponent: () =>
          import('./features/carga-asignaciones/carga-asignaciones').then((m) => m.CargaAsignaciones),
        title: 'Carga de asignaciones · UNO Contact CRM',
      },
      { path: 'acceso-denegado', component: AccesoDenegado, title: 'Acceso denegado · UNO Contact CRM' },
    ],
  },
  { path: '**', redirectTo: '' },
];
