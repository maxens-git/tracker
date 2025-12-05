import { definePreset } from '@primeuix/themes';
import Aura from '@primeuix/themes/aura';

const Preset = definePreset(Aura, {
    semantic: {
        // --- 1. PALETTES SÉMANTIQUES (Basées sur Zinc) ---
        primary: {
            50: '{zinc.50}',
            100: '{zinc.100}',
            200: '{zinc.200}',
            300: '{zinc.300}',
            400: '{zinc.400}',
            500: '{zinc.500}',
            600: '{zinc.600}',
            700: '{zinc.700}',
            800: '{zinc.800}',
            900: '{zinc.900}',
            950: '{zinc.950}'
        },
        // Vos autres couleurs (Secondary, Success, Danger, Warning) sont bonnes.
        secondary: { /* ... inchangé ... */ },
        success: { /* ... inchangé ... */ },
        danger: { /* ... inchangé ... */ },
        warning: { /* ... inchangé ... */ },

        // --- 2. SCHÉMAS DE COULEURS (Light/Dark Mode) ---
        colorScheme: {
            light: {
                // Le mode clair est bien défini, mais ajustons 'primary' pour l'ombre.
                primary: {
                    color: '{zinc.900}',
                    inverseColor: '#ffffff',
                    hoverColor: '{zinc.800}',
                    activeColor: '{zinc.700}',
                    shadow: '0 4px 12px rgba(0,0,0,0.1)' // Ombre légèrement plus douce
                },
                secondary: { /* ... inchangé ... */ },
                success: { /* ... inchangé ... */ },
                danger: { /* ... inchangé ... */ },
                warning: { /* ... inchangé ... */ },
                
                // AJOUTS MAJEURS : Couleurs de surface et bordures
                surface: {
                    0: '#ffffff',
                    50: '{zinc.50}',
                    100: '{zinc.100}',
                    200: '{zinc.200}',
                    300: '{zinc.300}',
                    400: '{zinc.400}',
                    500: '{zinc.500}',
                    600: '{zinc.600}',
                    700: '{zinc.700}',
                    800: '{zinc.800}',
                    900: '{zinc.900}',
                    950: '{zinc.950}',
                    // Définition de la bordure claire
                    border: '{zinc.300}',
                    text: '{zinc.900}',
                    textSecondary: '{zinc.500}'
                }
            },
            dark: {
                // AJUSTEMENT : Harmonisation du mode sombre avec la palette Zinc
                primary: {
                    color: '{zinc.50}', // Texte blanc/très clair
                    inverseColor: '{zinc.950}', // Fond sombre
                    hoverColor: '{zinc.100}',
                    activeColor: '{zinc.200}',
                    borderColor: '{zinc.50}',
                    shadow: '0 4px 12px rgba(0,0,0,0.4)' // Ombre plus prononcée en dark mode
                },
                secondary: { /* ... inchangé (ajustement possible des couleurs pour plus de contraste) ... */ },
                success: { /* ... inchangé ... */ },
                danger: { /* ... inchangé ... */ },
                warning: { /* ... inchangé ... */ },
                
                // AJOUTS MAJEURS : Couleurs de surface du mode sombre
                surface: {
                    0: '{zinc.950}', // Le fond le plus sombre
                    50: '{zinc.900}',
                    100: '{zinc.800}',
                    200: '{zinc.700}',
                    300: '{zinc.600}',
                    400: '{zinc.500}',
                    500: '{zinc.400}',
                    600: '{zinc.300}',
                    700: '{zinc.200}',
                    800: '{zinc.100}',
                    900: '{zinc.50}',
                    950: '#ffffff',
                    // Définition de la bordure sombre
                    border: '{zinc.700}',
                    text: '{zinc.50}',
                    textSecondary: '{zinc.400}'
                }
            }
        }
    },
    // --- 3. PARAMÈTRES GLOBAUX DU THÈME ---
    theme: {
        borderRadius: '10px',
        fontFamily: 'Space Grotesk, Inter, system-ui, sans-serif',
        fontSize: '16px',
        // AJUSTEMENT : Utilisation de la variable box shadow définie dans semantic
        boxShadow: '0 4px 12px rgba(0,0,0,0.08)',
        borderWidth: '2px',
        
        // AJOUT : Éléments de formulaire (inputs) pour correspondre au design arrondi
        input: {
            // Un rayon d'input légèrement plus petit que le global pour une hiérarchie visuelle
            borderRadius: '8px', 
            // Améliorer l'apparence du focus pour le dark mode
            focusRing: {
                light: '0 0 0 0.2rem rgba(39, 39, 42, 0.25)', // Utilise zinc.900
                dark: '0 0 0 0.2rem rgba(255, 255, 255, 0.15)' // Moins intrusif en dark
            }
        },
        // AJOUT : Boutons
        button: {
            borderRadius: '10px' // Cohérent avec le global
        },
        // AJOUT : Card (Conteneurs)
        card: {
            // Pour que les cartes aient la couleur de surface 0 (fond) et une bordure
            background: 'var(--p-surface-0)',
            borderColor: 'var(--p-surface-border)',
            borderWidth: '1px' // Moins épais que le global (2px) pour les bordures standard
        },
        // AJOUT : Menu (similaire aux cartes)
        menu: {
            background: 'var(--p-surface-0)',
            borderColor: 'var(--p-surface-border)',
            borderWidth: '1px'
        },

        // Les couleurs de fond globales sont maintenant gérées par `surface` (0 et 50)
        background: {
             light: 'var(--p-surface-50)', // Fond général plus clair que le blanc pour la profondeur
             dark: 'var(--p-surface-950)' // Le fond le plus sombre
        }
    }
});

export default Preset;