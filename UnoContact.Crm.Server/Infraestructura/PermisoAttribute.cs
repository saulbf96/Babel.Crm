using Microsoft.AspNetCore.Authorization;

namespace UnoContact.Crm.Server.Infraestructura;

/// <summary>Exige el permiso de una opción de menú (clave de CatalogoMenu), ej. [Permiso("bajas")].</summary>
public sealed class PermisoAttribute(string clave) : AuthorizeAttribute($"permiso:{clave}");
