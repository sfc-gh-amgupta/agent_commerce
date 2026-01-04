#!/usr/bin/env python3
"""
Professional Invoice Generator
Creates a sample retail invoice PDF with modern styling
"""

from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.enums import TA_LEFT, TA_RIGHT, TA_CENTER
from datetime import datetime, timedelta
import os


class InvoiceGenerator:
    def __init__(self):
        self.styles = getSampleStyleSheet()
        self.setup_custom_styles()
    
    def setup_custom_styles(self):
        """Setup custom paragraph styles for the invoice"""
        self.styles.add(ParagraphStyle(
            name='CompanyName',
            parent=self.styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#2C3E50'),
            spaceAfter=6,
            alignment=TA_LEFT
        ))
        
        self.styles.add(ParagraphStyle(
            name='InvoiceTitle',
            parent=self.styles['Heading1'],
            fontSize=28,
            textColor=colors.HexColor('#E74C3C'),
            spaceAfter=12,
            alignment=TA_RIGHT
        ))
        
        self.styles.add(ParagraphStyle(
            name='SectionHeader',
            parent=self.styles['Heading2'],
            fontSize=14,
            textColor=colors.HexColor('#34495E'),
            spaceAfter=6,
            spaceBefore=12
        ))
        
        self.styles.add(ParagraphStyle(
            name='AddressStyle',
            parent=self.styles['Normal'],
            fontSize=10,
            textColor=colors.HexColor('#7F8C8D'),
            spaceAfter=3
        ))
    
    def create_header(self):
        """Create the invoice header with company info and invoice title"""
        header_data = [
            [
                Paragraph("TechMart Electronics", self.styles['CompanyName']),
                Paragraph("INVOICE", self.styles['InvoiceTitle'])
            ],
            [
                Paragraph("123 Technology Boulevard<br/>San Francisco, CA 94105<br/>Phone: (555) 123-4567<br/>Email: billing@techmart.com", self.styles['AddressStyle']),
                ""
            ]
        ]
        
        header_table = Table(header_data, colWidths=[4*inch, 3*inch])
        header_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('ALIGN', (0, 0), (0, -1), 'LEFT'),
            ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ]))
        
        return header_table
    
    def create_invoice_details(self):
        """Create invoice number, date, and customer information"""
        invoice_date = datetime.now()
        due_date = invoice_date + timedelta(days=30)
        
        details_data = [
            ["Invoice #:", "INV-2024-001"],
            ["Invoice Date:", invoice_date.strftime("%B %d, %Y")],
            ["Due Date:", due_date.strftime("%B %d, %Y")],
            ["", ""],
            ["Bill To:", ""],
            ["", "Digital Solutions Inc."],
            ["", "456 Business Park Drive"],
            ["", "Austin, TX 78701"],
            ["", "Contact: Sarah Johnson"],
            ["", "Phone: (555) 987-6543"]
        ]
        
        details_table = Table(details_data, colWidths=[1.5*inch, 3*inch])
        details_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
            ('ALIGN', (1, 0), (1, -1), 'LEFT'),
            ('TEXTCOLOR', (0, 0), (0, 3), colors.HexColor('#2C3E50')),
            ('TEXTCOLOR', (0, 4), (0, 4), colors.HexColor('#E74C3C')),
            ('FONTNAME', (0, 4), (0, 4), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 4), (0, 4), 12),
        ]))
        
        return details_table
    
    def create_items_table(self):
        """Create the main items table with products and pricing"""
        items_data = [
            ["Item", "Description", "Qty", "Unit Price", "Total"],
            ["LT-001", "Laptop - Dell XPS 13, 16GB RAM, 512GB SSD", "2", "$1,299.99", "$2,599.98"],
            ["MON-002", "Monitor - 27\" 4K USB-C Display", "3", "$449.99", "$1,349.97"],
            ["KB-003", "Wireless Keyboard - Mechanical RGB", "5", "$129.99", "$649.95"],
            ["MS-004", "Wireless Mouse - Ergonomic Design", "5", "$79.99", "$399.95"],
            ["HD-005", "External Hard Drive - 2TB USB 3.0", "1", "$89.99", "$89.99"],
            ["CAB-006", "USB-C Cables - 6ft (Pack of 3)", "2", "$24.99", "$49.98"],
            ["", "", "", "", ""],
            ["", "", "", "Subtotal:", "$5,139.82"],
            ["", "", "", "Tax (8.5%):", "$436.88"],
            ["", "", "", "Shipping:", "$25.00"],
            ["", "", "", "", ""],
            ["", "", "", "TOTAL:", "$5,601.70"]
        ]
        
        items_table = Table(items_data, colWidths=[0.8*inch, 3.2*inch, 0.6*inch, 1*inch, 1*inch])
        
        # Style the table
        items_table.setStyle(TableStyle([
            # Header row styling
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#34495E')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 11),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            
            # Data rows styling
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 9),
            ('ALIGN', (0, 1), (0, -1), 'CENTER'),  # Item codes
            ('ALIGN', (1, 1), (1, -1), 'LEFT'),    # Descriptions
            ('ALIGN', (2, 1), (2, -1), 'CENTER'),  # Quantities
            ('ALIGN', (3, 1), (-1, -1), 'RIGHT'),  # Prices and totals
            
            # Alternating row colors for data
            ('BACKGROUND', (0, 1), (-1, 6), colors.white),
            ('BACKGROUND', (0, 2), (-1, 2), colors.HexColor('#F8F9FA')),
            ('BACKGROUND', (0, 4), (-1, 4), colors.HexColor('#F8F9FA')),
            ('BACKGROUND', (0, 6), (-1, 6), colors.HexColor('#F8F9FA')),
            
            # Subtotal section
            ('FONTNAME', (3, 8), (-1, 10), 'Helvetica-Bold'),
            ('FONTSIZE', (3, 8), (-1, 10), 10),
            ('BACKGROUND', (3, 8), (-1, 10), colors.HexColor('#ECF0F1')),
            
            # Total row
            ('FONTNAME', (3, 12), (-1, 12), 'Helvetica-Bold'),
            ('FONTSIZE', (3, 12), (-1, 12), 14),
            ('BACKGROUND', (3, 12), (-1, 12), colors.HexColor('#E74C3C')),
            ('TEXTCOLOR', (3, 12), (-1, 12), colors.white),
            
            # Grid lines
            ('GRID', (0, 0), (-1, 6), 1, colors.HexColor('#BDC3C7')),
            ('LINEBELOW', (3, 10), (-1, 10), 2, colors.HexColor('#34495E')),
            ('BOX', (3, 12), (-1, 12), 2, colors.HexColor('#C0392B')),
            
            # Padding
            ('TOPPADDING', (0, 0), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ]))
        
        return items_table
    
    def create_footer(self):
        """Create invoice footer with payment terms and notes"""
        footer_content = [
            Paragraph("<b>Payment Terms:</b>", self.styles['SectionHeader']),
            Paragraph("• Payment is due within 30 days of invoice date", self.styles['Normal']),
            Paragraph("• Late payments subject to 1.5% monthly service charge", self.styles['Normal']),
            Paragraph("• Please include invoice number with payment", self.styles['Normal']),
            Spacer(1, 0.2*inch),
            Paragraph("<b>Notes:</b>", self.styles['SectionHeader']),
            Paragraph("Thank you for your business! All items come with manufacturer warranty. For technical support, please contact our help desk at support@techmart.com or call (555) 123-HELP.", self.styles['Normal']),
            Spacer(1, 0.3*inch),
            Paragraph("TechMart Electronics - Your Technology Partner", 
                     ParagraphStyle('Footer', parent=self.styles['Normal'], 
                                  fontSize=8, textColor=colors.HexColor('#7F8C8D'), 
                                  alignment=TA_CENTER))
        ]
        
        return footer_content
    
    def generate_invoice(self, filename="sample_invoice.pdf"):
        """Generate the complete invoice PDF"""
        # Create the PDF document
        doc = SimpleDocTemplate(
            filename,
            pagesize=letter,
            rightMargin=0.75*inch,
            leftMargin=0.75*inch,
            topMargin=0.75*inch,
            bottomMargin=0.75*inch
        )
        
        # Build the story (content)
        story = []
        
        # Add header
        story.append(self.create_header())
        story.append(Spacer(1, 0.3*inch))
        
        # Add invoice details
        story.append(self.create_invoice_details())
        story.append(Spacer(1, 0.4*inch))
        
        # Add items table
        story.append(self.create_items_table())
        story.append(Spacer(1, 0.3*inch))
        
        # Add footer
        story.extend(self.create_footer())
        
        # Build the PDF
        doc.build(story)
        
        return filename


def main():
    """Main function to generate the sample invoice"""
    print("🧾 Generating sample retail invoice...")
    
    # Create invoice generator
    generator = InvoiceGenerator()
    
    # Generate the invoice
    output_file = "/Users/amgupta/Documents/Snowflake/Demo/sample_invoice.pdf"
    generator.generate_invoice(output_file)
    
    print(f"✅ Invoice generated successfully: {output_file}")
    print(f"📄 File size: {os.path.getsize(output_file) / 1024:.1f} KB")
    
    # Display invoice summary
    print("\n📋 Invoice Summary:")
    print("   Company: TechMart Electronics")
    print("   Customer: Digital Solutions Inc.")
    print("   Invoice #: INV-2024-001")
    print("   Total Amount: $5,601.70")
    print("   Items: 6 different products")


if __name__ == "__main__":
    main()


