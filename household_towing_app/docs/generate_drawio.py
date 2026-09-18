import html
import os

tables = {
    "T_USERS": {
        "x": 50, "y": 50, "w": 200, "name": "USERS",
        "fields": [
            ("PK", "id"), ("", "name"), ("", "email"), ("", "phone"), 
            ("", "role"), ("", "createdAt"), ("", "profileImageUrl")
        ]
    },
    "T_PROVIDERS": {
        "x": 500, "y": 50, "w": 220, "name": "PROVIDERS",
        "fields": [
            ("PK, FK", "id"), ("", "specialty"), ("", "rating"), ("", "totalReviews"), 
            ("", "isAvailable"), ("", "companyName"), ("", "isApproved")
        ]
    },
    "T_EMPLOYEES": {
        "x": 950, "y": 50, "w": 200, "name": "EMPLOYEES",
        "fields": [
            ("PK, FK", "id"), ("FK", "providerId"), ("", "vehicleType"), 
            ("", "licenseNumber"), ("", "isAvailable")
        ]
    },
    "T_BOOKINGS": {
        "x": 50, "y": 550, "w": 220, "name": "BOOKINGS",
        "fields": [
            ("PK", "id"), ("FK", "customerId"), ("FK", "assignedProviderId"), 
            ("", "serviceType"), ("", "status"), ("", "estimatedCost"), ("", "createdAt")
        ]
    },
    "T_TASKS": {
        "x": 500, "y": 550, "w": 220, "name": "TASKS",
        "fields": [
            ("PK", "id"), ("FK", "bookingId"), ("FK", "assignedDriverId"), 
            ("", "status"), ("", "location"), ("", "latitude"), ("", "longitude")
        ]
    },
    "T_ASSETS": {
        "x": 950, "y": 550, "w": 200, "name": "ASSETS",
        "fields": [
            ("PK", "id"), ("FK", "ownerId"), ("", "type"), 
            ("", "category"), ("", "status"), ("FK", "assignedTo")
        ]
    },
    "T_TRANSACTIONS": {
        "x": 50, "y": 1050, "w": 220, "name": "TRANSACTIONS",
        "fields": [
            ("PK", "id"), ("FK", "bookingId"), ("FK", "customerId"), 
            ("FK", "providerId"), ("", "amount"), ("", "paymentStatus")
        ]
    },
    "T_REVIEWS": {
        "x": 500, "y": 1050, "w": 220, "name": "REVIEWS",
        "fields": [
            ("PK", "id"), ("FK", "providerId"), ("FK", "customerId"), 
            ("", "rating"), ("", "comment")
        ]
    },
    "T_MESSAGES": {
        "x": 950, "y": 1050, "w": 200, "name": "MESSAGES",
        "fields": [
            ("PK", "id"), ("FK", "bookingId"), ("FK", "senderId"), 
            ("FK", "receiverId"), ("", "text"), ("", "timestamp")
        ]
    }
}

edges = [
    # (Source, Target, startArrow, endArrow)
    ("T_USERS", "T_PROVIDERS_R0", "ERmandOne", "ERzeroToOne"), # 1 to 1
    ("T_USERS", "T_EMPLOYEES_R0", "ERmandOne", "ERzeroToOne"), # 1 to 1
    ("T_PROVIDERS", "T_EMPLOYEES_R1", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_USERS", "T_BOOKINGS_R1", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_PROVIDERS", "T_BOOKINGS_R2", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_BOOKINGS", "T_TASKS_R1", "ERmandOne", "ERzeroToOne"), # 1 to 1
    ("T_EMPLOYEES", "T_TASKS_R2", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_PROVIDERS", "T_ASSETS_R1", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_EMPLOYEES", "T_ASSETS_R5", "ERzeroToMany", "ERzeroToMany"), # Many to Many
    ("T_BOOKINGS", "T_TRANSACTIONS_R1", "ERmandOne", "ERmandOne"), # 1 to 1
    ("T_USERS", "T_TRANSACTIONS_R2", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_PROVIDERS", "T_TRANSACTIONS_R3", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_USERS", "T_REVIEWS_R2", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_PROVIDERS", "T_REVIEWS_R1", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_BOOKINGS", "T_MESSAGES_R1", "ERmandOne", "ERzeroToMany"), # 1 to Many
    ("T_USERS", "T_MESSAGES_R2", "ERmandOne", "ERzeroToMany"), # 1 to Many
]

xml_parts = []
xml_parts.append('<?xml version="1.0" encoding="UTF-8"?>')
xml_parts.append('<mxfile host="Electron" modified="2024-01-01T00:00:00.000Z" agent="Mozilla/5.0" version="21.0.0" type="device">')
xml_parts.append('  <diagram id="diagram_1" name="Data Dictionary ERD">')
xml_parts.append('    <mxGraphModel dx="1400" dy="1400" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1100" pageHeight="1100" math="0" shadow="0">')
xml_parts.append('      <root>')
xml_parts.append('        <mxCell id="0" />')
xml_parts.append('        <mxCell id="1" parent="0" />')

# Generate Tables
for table_id, data in tables.items():
    t_name = data['name']
    fields = data['fields']
    x = data['x']
    y = data['y']
    w = data['w']
    row_h = 30
    h = 30 + (len(fields) * row_h)
    
    # Table container
    style_table = "shape=table;startSize=30;container=1;collapsible=1;childLayout=tableLayout;fixedRows=1;rowLines=0;fontStyle=1;align=center;"
    xml_parts.append(f'''        <mxCell id="{table_id}" value="{t_name}" style="{style_table}" vertex="1" parent="1">
          <mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry" />
        </mxCell>''')
        
    for i, (pkfk, field_name) in enumerate(fields):
        row_id = f"{table_id}_R{i}"
        cell1_id = f"{table_id}_C1_{i}"
        cell2_id = f"{table_id}_C2_{i}"
        current_y = 30 + (i * row_h)
        
        # Row container
        style_row = "shape=tableRow;horizontal=0;startSize=0;swimlaneHead=0;swimlaneBody=0;top=0;left=0;bottom=0;right=0;collapsible=0;dropTarget=0;fillColor=none;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;"
        xml_parts.append(f'''        <mxCell id="{row_id}" value="" style="{style_row}" vertex="1" parent="{table_id}">
          <mxGeometry y="{current_y}" width="{w}" height="{row_h}" as="geometry" />
        </mxCell>''')
        
        # Column 1 (PK/FK)
        style_c1 = "shape=partialRectangle;html=1;whiteSpace=wrap;connectable=0;fillColor=none;top=0;left=0;bottom=0;right=0;overflow=hidden;"
        xml_parts.append(f'''        <mxCell id="{cell1_id}" value="{pkfk}" style="{style_c1}" vertex="1" parent="{row_id}">
          <mxGeometry width="50" height="{row_h}" as="geometry" />
        </mxCell>''')
        
        # Column 2 (Field Name)
        style_c2 = "shape=partialRectangle;html=1;whiteSpace=wrap;connectable=0;fillColor=none;top=0;left=0;bottom=0;right=0;align=left;spacingLeft=6;overflow=hidden;"
        w2 = w - 50
        xml_parts.append(f'''        <mxCell id="{cell2_id}" value="{field_name}" style="{style_c2}" vertex="1" parent="{row_id}">
          <mxGeometry x="50" width="{w2}" height="{row_h}" as="geometry" />
        </mxCell>''')

# Add Edges
for i, (source, target, startArrow, endArrow) in enumerate(edges):
    edge_id = f"E_{i}"
    # Use standard orthogonal edge style with proper ERD Crow's Foot arrows
    style = f"html=1;edgeStyle=orthogonalEdgeStyle;rounded=1;jettySize=auto;orthogonalLoop=1;strokeColor=#666666;strokeWidth=2;startArrow={startArrow};endArrow={endArrow};startFill=0;endFill=0;"
    xml_parts.append(f'''        <mxCell id="{edge_id}" style="{style}" edge="1" parent="1" source="{source}" target="{target}">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>''')

xml_parts.append('      </root>')
xml_parts.append('    </mxGraphModel>')
xml_parts.append('  </diagram>')
xml_parts.append('</mxfile>')

out_path = r"c:\code\DUALSERVE\household_towing_app\docs\Data_Dictionary_ERD.drawio"
with open(out_path, "w", encoding="utf-8") as f:
    f.write('\n'.join(xml_parts))

print("SUCCESS")
