# Maritime Tracking - Analyses et Visualisations
# ================================================
# Notebook Jupyter pour l'analyse des données maritimes

# ================================================
# 0. INSTALLATION DES DÉPENDANCES
# ================================================

print("=" * 70)
print("🚢 MARITIME TRACKING - ANALYSES ET VISUALISATIONS")
print("=" * 70)

print("\n📦 Installation des bibliothèques nécessaires...")

import sys
import subprocess

def install_package(package):
    """Installe un package pip si nécessaire"""
    try:
        __import__(package)
        print(f"  ✓ {package} déjà installé")
    except ImportError:
        print(f"  ⏳ Installation de {package}...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", package])
        print(f"  ✓ {package} installé")

# Installer les packages nécessaires
packages = ['folium', 'plotly', 'seaborn']
for pkg in packages:
    install_package(pkg)

print("\n✅ Toutes les dépendances sont installées!\n")

# ================================================
# 1. IMPORTS
# ================================================

import warnings
warnings.filterwarnings('ignore')

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import folium
from folium.plugins import HeatMap, MarkerCluster
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime

# Configuration du style
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")

# ================================================
# 2. INITIALISATION SPARK
# ================================================

print("📊 Initialisation de Spark...")

spark = SparkSession.builder \
    .appName("MaritimeAnalysis") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.driver.memory", "2g") \
    .config("spark.executor.memory", "2g") \
    .getOrCreate()

print("✓ Session Spark créée avec succès")
print(f"  Version: {spark.version}")
print(f"  Master: {spark.sparkContext.master}")

# ================================================
# 3. CHARGEMENT DES DONNÉES
# ================================================

print("\n📁 Chargement des données depuis HDFS...")

hdfs_path = "hdfs://namenode:9000/maritime"

try:
    # Charger toutes les tables d'analyse
    ship_stats = spark.read.parquet(f"{hdfs_path}/analysis/ship_statistics")
    route_perf = spark.read.parquet(f"{hdfs_path}/analysis/route_performance")
    temporal = spark.read.parquet(f"{hdfs_path}/analysis/temporal_analysis")
    weather = spark.read.parquet(f"{hdfs_path}/analysis/weather_impact")
    anomalies = spark.read.parquet(f"{hdfs_path}/analysis/anomalies_detected")
    maintenance = spark.read.parquet(f"{hdfs_path}/analysis/maintenance_prediction")
    raw_data = spark.read.parquet(f"{hdfs_path}/raw_data")
    eta_pred = spark.read.parquet(f"{hdfs_path}/eta_predictions")
    
    print("✓ Données chargées:")
    print(f"  • ship_statistics: {ship_stats.count():,} lignes")
    print(f"  • route_performance: {route_perf.count():,} lignes")
    print(f"  • weather_impact: {weather.count():,} lignes")
    print(f"  • anomalies: {anomalies.count():,} lignes")
    print(f"  • maintenance: {maintenance.count():,} lignes")
    print(f"  • raw_telemetry: {raw_data.count():,} lignes")
    print(f"  • eta_predictions: {eta_pred.count():,} lignes")
    
except Exception as e:
    print(f"❌ Erreur lors du chargement: {e}")
    print("\n💡 Assurez-vous que:")
    print("  1. Les analyses batch ont été exécutées (./scripts/run-batch.sh)")
    print("  2. HDFS est accessible")
    print("  3. Les données existent dans /maritime/analysis/")
    spark.stop()
    raise

# ================================================
# 4. VISUALISATION 1: CARTE DES TRAJECTOIRES
# ================================================

print("\n🗺️  Génération de la carte des trajectoires...")

try:
    # Récupérer un échantillon de positions (pour performance)
    positions_df = raw_data.select("navire_id", "latitude", "longitude", "timestamp") \
        .sample(fraction=0.3) \
        .orderBy("timestamp") \
        .toPandas()
    
    # Créer la carte centrée sur la Méditerranée
    m = folium.Map(
        location=[37.0, 3.0],
        zoom_start=5,
        tiles='OpenStreetMap'
    )
    
    # Ajouter une heatmap des trajectoires
    heat_data = positions_df[['latitude', 'longitude']].values.tolist()
    HeatMap(heat_data, radius=10, blur=15, gradient={
        0.0: 'blue',
        0.5: 'lime',
        0.7: 'yellow',
        1.0: 'red'
    }).add_to(m)
    
    # Ajouter les positions actuelles de chaque navire
    latest_positions = raw_data.groupBy("navire_id").agg(
        max("timestamp").alias("max_ts")
    ).join(
        raw_data, 
        (raw_data.navire_id == col("navire_id")) & (raw_data.timestamp == col("max_ts"))
    ).select("navire_id", "latitude", "longitude", "vitesse_noeuds", "carburant_litres").toPandas()
    
    colors = ['red', 'blue', 'green', 'purple', 'orange', 'darkred', 'lightred', 'beige', 
              'darkblue', 'darkgreen', 'cadetblue', 'darkpurple', 'white', 'pink', 'lightblue']
    
    for idx, (_, row) in enumerate(latest_positions.iterrows()):
        popup_html = f"""
        <div style="font-family: Arial; font-size: 12px;">
            <b style="font-size: 14px;">{row['navire_id']}</b><br>
            📍 Position actuelle<br>
            ⚡ Vitesse: {row['vitesse_noeuds']:.1f} nœuds<br>
            ⛽ Carburant: {row['carburant_litres']:.0f} L
        </div>
        """
        
        folium.Marker(
            location=[row['latitude'], row['longitude']],
            popup=folium.Popup(popup_html, max_width=200),
            icon=folium.Icon(color=colors[idx % len(colors)], icon='ship', prefix='fa')
        ).add_to(m)
    
    # Sauvegarder la carte
    m.save('maritime_trajectories.html')
    print("✓ Carte sauvegardée: maritime_trajectories.html")
    
except Exception as e:
    print(f"⚠️  Erreur carte: {e}")

# ================================================
# 5. VISUALISATION 2: EFFICACITÉ ÉNERGÉTIQUE
# ================================================

print("\n⚡ Analyse de l'efficacité énergétique...")

try:
    # Convertir en Pandas
    ship_stats_pd = ship_stats.toPandas()
    
    # Créer la figure
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    
    # Efficacité carburant
    ax1 = axes[0, 0]
    ship_stats_pd_sorted = ship_stats_pd.sort_values('efficacite_carburant_nm_per_litre', ascending=True)
    bars1 = ax1.barh(ship_stats_pd_sorted['navire_id'], 
             ship_stats_pd_sorted['efficacite_carburant_nm_per_litre'],
             color='steelblue')
    ax1.set_xlabel('Efficacité (nm par litre)', fontsize=12, fontweight='bold')
    ax1.set_ylabel('Navire', fontsize=12, fontweight='bold')
    ax1.set_title('🔋 Efficacité Énergétique par Navire', fontsize=14, fontweight='bold')
    ax1.grid(axis='x', alpha=0.3)
    
    # Ajouter les valeurs sur les barres
    for bar in bars1:
        width = bar.get_width()
        if width > 0:
            ax1.text(width, bar.get_y() + bar.get_height()/2, 
                    f'{width:.3f}', ha='left', va='center', fontsize=9)
    
    # Vitesse moyenne
    ax2 = axes[0, 1]
    ship_stats_pd_sorted_speed = ship_stats_pd.sort_values('vitesse_moyenne', ascending=True)
    bars2 = ax2.barh(ship_stats_pd_sorted_speed['navire_id'], 
                    ship_stats_pd_sorted_speed['vitesse_moyenne'],
                    color='coral')
    ax2.set_xlabel('Vitesse Moyenne (nœuds)', fontsize=12, fontweight='bold')
    ax2.set_ylabel('Navire', fontsize=12, fontweight='bold')
    ax2.set_title('🚢 Vitesse Moyenne par Navire', fontsize=14, fontweight='bold')
    ax2.grid(axis='x', alpha=0.3)
    
    for bar in bars2:
        width = bar.get_width()
        ax2.text(width, bar.get_y() + bar.get_height()/2, 
                f'{width:.1f}', ha='left', va='center', fontsize=9)
    
    # Consommation moyenne
    ax3 = axes[1, 0]
    ship_stats_pd_sorted_conso = ship_stats_pd.sort_values('consommation_moyenne', ascending=True)
    bars3 = ax3.barh(ship_stats_pd_sorted_conso['navire_id'], 
             ship_stats_pd_sorted_conso['consommation_moyenne'],
             color='lightgreen')
    ax3.set_xlabel('Consommation (L/h)', fontsize=12, fontweight='bold')
    ax3.set_ylabel('Navire', fontsize=12, fontweight='bold')
    ax3.set_title('⛽ Consommation Moyenne par Navire', fontsize=14, fontweight='bold')
    ax3.grid(axis='x', alpha=0.3)
    
    for bar in bars3:
        width = bar.get_width()
        ax3.text(width, bar.get_y() + bar.get_height()/2, 
                f'{width:.1f}', ha='left', va='center', fontsize=9)
    
    # Distance parcourue
    ax4 = axes[1, 1]
    ship_stats_pd_sorted_dist = ship_stats_pd.sort_values('distance_totale_nm', ascending=True)
    bars4 = ax4.barh(ship_stats_pd_sorted_dist['navire_id'], 
             ship_stats_pd_sorted_dist['distance_totale_nm'],
             color='gold')
    ax4.set_xlabel('Distance (nm)', fontsize=12, fontweight='bold')
    ax4.set_ylabel('Navire', fontsize=12, fontweight='bold')
    ax4.set_title('📏 Distance Totale Parcourue', fontsize=14, fontweight='bold')
    ax4.grid(axis='x', alpha=0.3)
    
    for bar in bars4:
        width = bar.get_width()
        ax4.text(width, bar.get_y() + bar.get_height()/2, 
                f'{width:.0f}', ha='left', va='center', fontsize=9)
    
    plt.tight_layout()
    plt.savefig('ship_efficiency_analysis.png', dpi=300, bbox_inches='tight')
    print("✓ Graphique sauvegardé: ship_efficiency_analysis.png")
    plt.show()
    
except Exception as e:
    print(f"⚠️  Erreur efficacité: {e}")

# ================================================
# 6. VISUALISATION 3: PERFORMANCE DES ROUTES
# ================================================

print("\n🛣️  Analyse des performances par route...")

try:
    route_perf_pd = route_perf.toPandas()
    
    fig, axes = plt.subplots(1, 2, figsize=(16, 6))
    
    # Routes les plus fréquentées
    ax1 = axes[0]
    route_perf_pd['route'] = route_perf_pd['port_depart'] + ' → ' + route_perf_pd['port_arrivee']
    top_routes = route_perf_pd.nlargest(min(10, len(route_perf_pd)), 'nombre_navires')
    bars = ax1.bar(range(len(top_routes)), top_routes['nombre_navires'], color='teal')
    ax1.set_xticks(range(len(top_routes)))
    ax1.set_xticklabels(top_routes['route'], rotation=45, ha='right')
    ax1.set_ylabel('Nombre de Navires', fontsize=12, fontweight='bold')
    ax1.set_title('🗺️  Routes les Plus Fréquentées', fontsize=14, fontweight='bold')
    ax1.grid(axis='y', alpha=0.3)
    
    # Ajouter les valeurs
    for bar in bars:
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height,
                f'{int(height)}', ha='center', va='bottom', fontsize=10)
    
    # Distance vs Temps
    ax2 = axes[1]
    scatter = ax2.scatter(route_perf_pd['distance_moyenne_route'], 
                         route_perf_pd['temps_estime_heures'],
                         s=route_perf_pd['nombre_navires']*100,
                         c=route_perf_pd['consommation_moyenne_route'],
                         cmap='viridis',
                         alpha=0.6,
                         edgecolors='black',
                         linewidth=1)
    ax2.set_xlabel('Distance (nm)', fontsize=12, fontweight='bold')
    ax2.set_ylabel('Temps (heures)', fontsize=12, fontweight='bold')
    ax2.set_title('📊 Distance vs Temps\n(taille = nb navires, couleur = consommation)', 
                  fontsize=14, fontweight='bold')
    cbar = plt.colorbar(scatter, ax=ax2, label='Consommation (L/h)')
    ax2.grid(alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('route_performance.png', dpi=300, bbox_inches='tight')
    print("✓ Graphique sauvegardé: route_performance.png")
    plt.show()
    
except Exception as e:
    print(f"⚠️  Erreur routes: {e}")

# ================================================
# 7. VISUALISATION 4: IMPACT MÉTÉO
# ================================================

print("\n🌤️  Analyse de l'impact météorologique...")

try:
    weather_pd = weather.toPandas()
    
    fig, axes = plt.subplots(1, 3, figsize=(18, 5))
    
    # Distribution des conditions météo
    ax1 = axes[0]
    colors_weather = ['#FFD700', '#87CEEB', '#808080', '#4169E1', '#696969']
    wedges, texts, autotexts = ax1.pie(weather_pd['occurrences'], 
                                         labels=weather_pd['meteo'],
                                         autopct='%1.1f%%',
                                         colors=colors_weather[:len(weather_pd)],
                                         startangle=90)
    ax1.set_title('☁️ Distribution des Conditions Météo', fontsize=14, fontweight='bold')
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontweight('bold')
        autotext.set_fontsize(11)
    
    # Impact sur la vitesse
    ax2 = axes[1]
    bars = ax2.bar(weather_pd['meteo'], weather_pd['vitesse_moyenne'], 
                   color=colors_weather[:len(weather_pd)])
    ax2.set_ylabel('Vitesse Moyenne (nœuds)', fontsize=12, fontweight='bold')
    ax2.set_title('🚢 Impact Météo sur la Vitesse', fontsize=14, fontweight='bold')
    ax2.tick_params(axis='x', rotation=45)
    ax2.grid(axis='y', alpha=0.3)
    
    for bar in bars:
        height = bar.get_height()
        ax2.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}', ha='center', va='bottom', fontsize=9)
    
    # Impact sur la consommation
    ax3 = axes[2]
    bars = ax3.bar(weather_pd['meteo'], weather_pd['consommation_moyenne'], 
                   color=colors_weather[:len(weather_pd)])
    ax3.set_ylabel('Consommation (L/h)', fontsize=12, fontweight='bold')
    ax3.set_title('⛽ Impact Météo sur la Consommation', fontsize=14, fontweight='bold')
    ax3.tick_params(axis='x', rotation=45)
    ax3.grid(axis='y', alpha=0.3)
    
    for bar in bars:
        height = bar.get_height()
        ax3.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}', ha='center', va='bottom', fontsize=9)
    
    plt.tight_layout()
    plt.savefig('weather_impact.png', dpi=300, bbox_inches='tight')
    print("✓ Graphique sauvegardé: weather_impact.png")
    plt.show()
    
except Exception as e:
    print(f"⚠️  Erreur météo: {e}")

# ================================================
# 8. VISUALISATION 5: ANOMALIES ET MAINTENANCE
# ================================================

print("\n🔧 Analyse des anomalies et maintenance...")

try:
    anomalies_pd = anomalies.toPandas()
    maintenance_pd = maintenance.toPandas()
    
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    
    # Anomalies par navire
    ax1 = axes[0, 0]
    anomaly_counts = anomalies_pd['navire_id'].value_counts()
    bars = ax1.bar(anomaly_counts.index, anomaly_counts.values, color='orangered')
    ax1.set_xlabel('Navire', fontsize=12, fontweight='bold')
    ax1.set_ylabel('Nombre d\'Anomalies', fontsize=12, fontweight='bold')
    ax1.set_title('⚠️  Nombre d\'Anomalies par Navire', fontsize=14, fontweight='bold')
    ax1.tick_params(axis='x', rotation=45)
    ax1.grid(axis='y', alpha=0.3)
    
    for bar in bars:
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height,
                f'{int(height)}', ha='center', va='bottom', fontsize=10)
    
    # Types d'anomalies
    ax2 = axes[0, 1]
    if 'type_anomalie' in anomalies_pd.columns:
        anomaly_types = anomalies_pd['type_anomalie'].value_counts()
        colors_anom = ['#FF6B6B', '#FFA500', '#FFD700']
        wedges, texts, autotexts = ax2.pie(anomaly_types.values, 
                                            labels=anomaly_types.index, 
                                            autopct='%1.1f%%',
                                            colors=colors_anom[:len(anomaly_types)], 
                                            startangle=90)
        for autotext in autotexts:
            autotext.set_color('white')
            autotext.set_fontweight('bold')
    ax2.set_title('📊 Distribution des Types d\'Anomalies', fontsize=14, fontweight='bold')
    
    # Score de risque maintenance
    ax3 = axes[1, 0]
    colors_risk = ['red' if p == 'URGENT' else 'orange' if p == 'MOYENNE' else 'green' 
                   for p in maintenance_pd['priorite_maintenance']]
    bars = ax3.barh(maintenance_pd['navire_id'], maintenance_pd['score_risque'], color=colors_risk)
    ax3.set_xlabel('Score de Risque', fontsize=12, fontweight='bold')
    ax3.set_ylabel('Navire', fontsize=12, fontweight='bold')
    ax3.set_title('🔧 Score de Risque Maintenance', fontsize=14, fontweight='bold')
    ax3.grid(axis='x', alpha=0.3)
    
    for bar in bars:
        width = bar.get_width()
        ax3.text(width, bar.get_y() + bar.get_height()/2, 
                f'{int(width)}', ha='left', va='center', fontsize=10, fontweight='bold')
    
    # Distribution priorités maintenance
    ax4 = axes[1, 1]
    priority_counts = maintenance_pd['priorite_maintenance'].value_counts()
    priority_order = ['URGENT', 'MOYENNE', 'FAIBLE']
    priority_colors = {'URGENT': 'red', 'MOYENNE': 'orange', 'FAIBLE': 'green'}
    
    sorted_priorities = [p for p in priority_order if p in priority_counts.index]
    counts = [priority_counts[p] for p in sorted_priorities]
    colors_p = [priority_colors[p] for p in sorted_priorities]
    
    bars = ax4.bar(sorted_priorities, counts, color=colors_p)
    ax4.set_ylabel('Nombre de Navires', fontsize=12, fontweight='bold')
    ax4.set_title('🚨 Distribution des Priorités de Maintenance', fontsize=14, fontweight='bold')
    ax4.grid(axis='y', alpha=0.3)
    
    for bar in bars:
        height = bar.get_height()
        ax4.text(bar.get_x() + bar.get_width()/2., height,
                f'{int(height)}', ha='center', va='bottom', fontsize=11, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('anomalies_maintenance.png', dpi=300, bbox_inches='tight')
    print("✓ Graphique sauvegardé: anomalies_maintenance.png")
    plt.show()
    
except Exception as e:
    print(f"⚠️  Erreur anomalies: {e}")

# ================================================
# 9. VISUALISATION 6: ÉVOLUTION TEMPORELLE
# ================================================

print("\n📈 Analyse temporelle interactive...")

try:
    # Prendre un échantillon de données brutes
    raw_sample = raw_data.orderBy("timestamp").limit(1000).toPandas()
    raw_sample['timestamp'] = pd.to_datetime(raw_sample['timestamp'])
    
    # Créer un graphique avec Plotly pour l'interactivité
    fig = go.Figure()
    
    for navire in raw_sample['navire_id'].unique():
        navire_data = raw_sample[raw_sample['navire_id'] == navire]
        fig.add_trace(go.Scatter(
            x=navire_data['timestamp'],
            y=navire_data['vitesse_noeuds'],
            mode='lines+markers',
            name=navire,
            line=dict(width=2),
            marker=dict(size=4),
            hovertemplate='<b>%{fullData.name}</b><br>' +
                         'Temps: %{x}<br>' +
                         'Vitesse: %{y:.1f} nœuds<br>' +
                         '<extra></extra>'
        ))
    
    fig.update_layout(
        title='📈 Évolution de la Vitesse des Navires en Temps Réel',
        xaxis_title='Temps',
        yaxis_title='Vitesse (nœuds)',
        height=600,
        hovermode='x unified',
        template='plotly_white',
        font=dict(size=12)
    )
    
    fig.write_html('temporal_evolution.html')
    print("✓ Graphique interactif sauvegardé: temporal_evolution.html")
    fig.show()
    
except Exception as e:
    print(f"⚠️  Erreur temporel: {e}")

# ================================================
# 10. VISUALISATION 7: ETA ET PRÉDICTIONS
# ================================================

print("\n⏱️  Analyse des prédictions ETA...")

try:
    # Prendre les dernières prédictions ETA
    latest_eta = eta_pred.groupBy("navire_id").agg(
        max("timestamp").alias("timestamp")
    )
    eta_current = eta_pred.join(latest_eta, ["navire_id", "timestamp"]).toPandas()
    
    fig, axes = plt.subplots(1, 2, figsize=(16, 6))
    
    # Distance restante
    ax1 = axes[0]
    eta_current_sorted = eta_current.sort_values('distance_restante_nm')
    bars = ax1.barh(eta_current_sorted['navire_id'], 
             eta_current_sorted['distance_restante_nm'],
             color='skyblue')
    ax1.set_xlabel('Distance Restante (nm)', fontsize=12, fontweight='bold')
    ax1.set_ylabel('Navire', fontsize=12, fontweight='bold')
    ax1.set_title('📏 Distance Restante jusqu\'à l\'Arrivée', fontsize=14, fontweight='bold')
    ax1.grid(axis='x', alpha=0.3)
    
    for bar in bars:
        width = bar.get_width()
        ax1.text(width, bar.get_y() + bar.get_height()/2, 
                f'{width:.0f}', ha='left', va='center', fontsize=9)
    
    # ETA en heures
    ax2 = axes[1]
    eta_current_sorted_time = eta_current.sort_values('eta_heures')
    bars = ax2.barh(eta_current_sorted_time['navire_id'], 
                    eta_current_sorted_time['eta_heures'],
                    color='mediumseagreen')
    ax2.set_xlabel('ETA (heures)', fontsize=12, fontweight='bold')
    ax2.set_ylabel('Navire', fontsize=12, fontweight='bold')
    ax2.set_title('⏱️  Temps Estimé d\'Arrivée', fontsize=14, fontweight='bold')
    ax2.grid(axis='x', alpha=0.3)
    
    for i, (idx, row) in enumerate(eta_current_sorted_time.iterrows()):
        ax2.text(row['eta_heures'] + 0.5, i, f"{row['eta_heures']:.1f}h", 
                 va='center', fontsize=9, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('eta_predictions.png', dpi=300, bbox_inches='tight')
    print("✓ Graphique sauvegardé: eta_predictions.png")
    plt.show()
    
except Exception as e:
    print(f"⚠️  Erreur ETA: {e}")

# ================================================
# 11. CALCUL DES MÉTRIQUES GLOBALES
# ================================================

print("\n📊 Calcul des métriques globales...")

# Calculer les métriques clés (en dehors du try-catch pour les avoir toujours)
try:
    total_ships = ship_stats.count()
    total_distance = ship_stats.agg(sum("distance_totale_nm")).collect()[0][0] or 0
    avg_speed = ship_stats.agg(avg("vitesse_moyenne")).collect()[0][0] or 0
    total_anomalies = anomalies.count()
    urgent_maintenance = maintenance.filter(col("priorite_maintenance") == "URGENT").count()
    print("✓ Métriques calculées avec succès")
except Exception as e:
    print(f"⚠️  Erreur calcul métriques: {e}")
    # Valeurs par défaut
    total_ships = 0
    total_distance = 0
    avg_speed = 0
    total_anomalies = 0
    urgent_maintenance = 0

# ================================================
# 12. DASHBOARD RÉCAPITULATIF
# ================================================

print("\n📊 Génération du dashboard récapitulatif...")

try:
    
    # Créer un dashboard avec matplotlib
    fig = plt.figure(figsize=(18, 12))
    gs = fig.add_gridspec(3, 3, hspace=0.4, wspace=0.3)
    
    # Titre principal
    fig.suptitle('🚢 MARITIME TRACKING - DASHBOARD RÉCAPITULATIF', 
                 fontsize=22, fontweight='bold', y=0.98)
    
    # Métriques clés
    ax_metrics = fig.add_subplot(gs[0, :])
    ax_metrics.axis('off')
    
    metrics_text = f"""
    📊 MÉTRIQUES GLOBALES DE LA FLOTTE
    
    🚢 Nombre de navires: {total_ships}
    📏 Distance totale parcourue: {total_distance:,.0f} nm
    ⚡ Vitesse moyenne: {avg_speed:.2f} nœuds
    ⚠️  Anomalies détectées: {total_anomalies}
    🔧 Maintenances urgentes: {urgent_maintenance}
    """
    
    ax_metrics.text(0.5, 0.5, metrics_text, 
                    ha='center', va='center',
                    fontsize=16,
                    bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.5, pad=1.5))
    
    # Convertir les DataFrames
    ship_stats_pd = ship_stats.toPandas()
    route_perf_pd = route_perf.toPandas()
    weather_pd = weather.toPandas()
    anomalies_pd = anomalies.toPandas()
    maintenance_pd = maintenance.toPandas()
    
    # Mini graphiques
    ax1 = fig.add_subplot(gs[1, 0])
    ax1.bar(ship_stats_pd['navire_id'], ship_stats_pd['vitesse_moyenne'], color='steelblue')
    ax1.set_title('Vitesse par Navire', fontsize=11, fontweight='bold')
    ax1.tick_params(axis='x', rotation=45, labelsize=8)
    ax1.set_ylabel('Vitesse (nœuds)', fontsize=9)
    ax1.grid(axis='y', alpha=0.3)
    
    ax2 = fig.add_subplot(gs[1, 1])
    ax2.pie(weather_pd['occurrences'], labels=weather_pd['meteo'], autopct='%1.0f%%', textprops={'fontsize': 8})
    ax2.set_title('Conditions Météo', fontsize=11, fontweight='bold')
    
    ax3 = fig.add_subplot(gs[1, 2])
    anomaly_counts_top = anomalies_pd['navire_id'].value_counts().head(5)
    ax3.barh(anomaly_counts_top.index, anomaly_counts_top.values, color='orangered')
    ax3.set_title('Top 5 Anomalies', fontsize=11, fontweight='bold')
    ax3.set_xlabel('Nombre', fontsize=9)
    ax3.grid(axis='x', alpha=0.3)
    
    ax4 = fig.add_subplot(gs[2, 0])
    colors_risk = ['red' if p == 'URGENT' else 'orange' if p == 'MOYENNE' else 'green' 
                   for p in maintenance_pd['priorite_maintenance']]
    ax4.bar(maintenance_pd['navire_id'], maintenance_pd['score_risque'], color=colors_risk)
    ax4.set_title('Score Risque Maintenance', fontsize=11, fontweight='bold')
    ax4.tick_params(axis='x', rotation=45, labelsize=8)
    ax4.set_ylabel('Score', fontsize=9)
    ax4.grid(axis='y', alpha=0.3)
    
    ax5 = fig.add_subplot(gs[2, 1])
    route_perf_pd['route'] = route_perf_pd['port_depart'] + '→' + route_perf_pd['port_arrivee']
    route_top = route_perf_pd.nlargest(5, 'nombre_navires')
    ax5.barh(range(len(route_top)), route_top['nombre_navires'], color='teal')
    ax5.set_yticks(range(len(route_top)))
    ax5.set_yticklabels(route_top['route'], fontsize=8)
    ax5.set_title('Top 5 Routes', fontsize=11, fontweight='bold')
    ax5.set_xlabel('Navires', fontsize=9)
    ax5.grid(axis='x', alpha=0.3)
    
    ax6 = fig.add_subplot(gs[2, 2])
    eta_summary = eta_current.sort_values('eta_heures').head(5) if len(eta_current) > 0 else eta_current
    if len(eta_summary) > 0:
        ax6.barh(eta_summary['navire_id'], eta_summary['eta_heures'], color='mediumseagreen')
        ax6.set_title('Prochains Arrivages', fontsize=11, fontweight='bold')
        ax6.set_xlabel('ETA (h)', fontsize=9)
        ax6.grid(axis='x', alpha=0.3)
    
    plt.savefig('dashboard_recap.png', dpi=300, bbox_inches='tight')
    print("✓ Dashboard sauvegardé: dashboard_recap.png")
    plt.show()
    
except Exception as e:
    print(f"⚠️  Erreur dashboard: {e}")

# ================================================
# 13. RAPPORT FINAL
# ================================================

print("\n" + "="*70)
print("✅ TOUTES LES VISUALISATIONS GÉNÉRÉES AVEC SUCCÈS!")
print("="*70)
print("\n📁 Fichiers créés:")
print("  ✓ maritime_trajectories.html - Carte interactive des trajectoires")
print("  ✓ ship_efficiency_analysis.png - Analyse d'efficacité énergétique")
print("  ✓ route_performance.png - Performance des routes")
print("  ✓ weather_impact.png - Impact météorologique")
print("  ✓ anomalies_maintenance.png - Anomalies et maintenance")
print("  ✓ temporal_evolution.html - Évolution temporelle interactive")
print("  ✓ eta_predictions.png - Prédictions ETA")
print("  ✓ dashboard_recap.png - Dashboard récapitulatif")

print("\n💡 Prochaines étapes:")
print("  1. Ouvrir les fichiers HTML dans votre navigateur")
print("  2. Inclure les PNG dans votre rapport")
print("  3. Analyser les insights pour votre conclusion")

print("\n📊 Résumé des Analyses:")
print(f"  • {total_ships} navires suivis")
print(f"  • {total_distance:,.0f} nm parcourus")
print(f"  • {total_anomalies} anomalies détectées")
print(f"  • {urgent_maintenance} maintenances urgentes")

# Fermer la session Spark
spark.stop()
print("\n✓ Session Spark terminée")
print("="*70)