#!/usr/bin/env python3
"""
Handwritten-Style Invoice Generator
Creates a sample retail invoice PDF that looks hand-filled
"""

from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.enums import TA_LEFT, TA_RIGHT, TA_CENTER
from reportlab.graphics.shapes import Line, Rect, Drawing
from reportlab.graphics import renderPDF
from datetime import datetime, timedelta
import os


class HandwrittenInvoiceGenerator:
    def __init__(self):
        self.styles = getSampleStyleSheet()
        self.setup_handwritten_styles()
    
    def setup_handwritten_styles(self):
        """Setup handwritten-style paragraph styles"""
        # Try to use a more casual font, fallback to Helvetica
        handwritten_font = 'Helvetica'  # Could be 'Comic Sans MS' if available
        
        self.styles.add(ParagraphStyle(
            name='HandwrittenTitle',
            parent=self.styles['Heading1'],
            fontName=handwritten_font,
            fontSize=20,
            textColor=colors.HexColor('#2E4057'),
            spaceAfter=8,
            alignment=TA_CENTER,
            leading=24
        ))
        
        self.styles.add(ParagraphStyle(
            name='HandwrittenHeader',
            parent=self.styles['Normal'],
            fontName=handwritten_font,
            fontSize=14,
            textColor=colors.HexColor('#1A252F'),
            spaceAfter=6,
            leading=18
        ))
        
        self.styles.add(ParagraphStyle(
            name='HandwrittenText',
            parent=self.styles['Normal'],
            fontName=handwritten_font,
            fontSize=11,
            textColor=colors.HexColor('#2E4057'),
            spaceAfter=4,
            leading=14
        ))
        
        self.styles.add(ParagraphStyle(
            name='HandwrittenSmall',
            parent=self.styles['Normal'],
            fontName=handwritten_font,
            fontSize=9,
            textColor=colors.HexColor('#4A5568'),
            spaceAfter=3,
            leading=12
        ))
    
    def create_form_lines(self, width, height=0.02*inch):
        """Create a drawing with horizontal lines to simulate form lines"""
        drawing = Drawing(width, height)
        drawing.add(Line(0, height/2, width, height/2, strokeColor=colors.HexColor('#CBD5E0'), strokeWidth=0.5))
        return drawing
    
    def create_header(self):
        """Create handwritten-style header"""
        header_content = []
        
        # Title with underline effect
        header_content.append(Paragraph("INVOICE", self.styles['HandwrittenTitle']))
        header_content.append(self.create_form_lines(7*inch))
        header_content.append(Spacer(1, 0.2*inch))
        
        # Company info in handwritten style
        company_info = """
        <b>From:</b> Mike's Electronics Store<br/>
        📍 456 Main Street, Downtown<br/>
        📞 (555) 234-5678<br/>
        ✉️ mike@electronicsstore.com
        """
        
        header_content.append(Paragraph(company_info, self.styles['HandwrittenText']))
        header_content.append(Spacer(1, 0.15*inch))
        
        return header_content
    
    def create_invoice_info(self):
        """Create handwritten-style invoice information"""
        invoice_date = datetime.now()
        due_date = invoice_date + timedelta(days=30)
        
        # Create a table that looks like filled form fields
        info_data = [
            ["Invoice #:", "2024-0087", "", "Date:", invoice_date.strftime("%m/%d/%Y")],
            ["", "", "", "", ""],
            ["Bill To:", "", "", "Due Date:", due_date.strftime("%m/%d/%Y")],
            ["", "Jennifer's Coffee Shop", "", "", ""],
            ["", "789 Brew Street", "", "Payment:", "Net 30"],
            ["", "Seattle, WA 98101", "", "", ""],
            ["", "Contact: Jennifer Martinez", "", "Terms:", "2/10 Net 30"],
            ["", "☎ (555) 876-5432", "", "", ""]
        ]
        
        info_table = Table(info_data, colWidths=[0.8*inch, 2.5*inch, 0.3*inch, 0.8*inch, 1.2*inch])
        info_table.setStyle(TableStyle([
            # Labels in "handwritten" style
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica'),
            ('FONTNAME', (3, 0), (3, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 11),
            ('TEXTCOLOR', (0, 0), (0, -1), colors.HexColor('#2E4057')),
            ('TEXTCOLOR', (3, 0), (3, -1), colors.HexColor('#2E4057')),
            
            # Filled-in values
            ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
            ('FONTNAME', (4, 0), (4, -1), 'Helvetica'),
            ('TEXTCOLOR', (1, 0), (1, -1), colors.HexColor('#1A252F')),
            ('TEXTCOLOR', (4, 0), (4, -1), colors.HexColor('#1A252F')),
            
            # Alignment
            ('ALIGN', (0, 0), (0, -1), 'RIGHT'),
            ('ALIGN', (3, 0), (3, -1), 'RIGHT'),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            
            # Add some lines under filled areas
            ('LINEBELOW', (1, 0), (1, 0), 0.5, colors.HexColor('#CBD5E0')),
            ('LINEBELOW', (4, 0), (4, 0), 0.5, colors.HexColor('#CBD5E0')),
            ('LINEBELOW', (1, 3), (1, 6), 0.5, colors.HexColor('#CBD5E0')),
            ('LINEBELOW', (4, 2), (4, 2), 0.5, colors.HexColor('#CBD5E0')),
            ('LINEBELOW', (4, 4), (4, 4), 0.5, colors.HexColor('#CBD5E0')),
            ('LINEBELOW', (4, 6), (4, 6), 0.5, colors.HexColor('#CBD5E0')),
        ]))
        
        return info_table
    
    def create_items_table(self):
        """Create handwritten-style items table"""
        # Header with handwritten feel
        items_data = [
            ["Item", "Description", "Qty", "Price", "Total"],
            ["", "", "", "", ""],
            ["Laptop", "MacBook Air 13\" - Silver", "1", "$999.00", "$999.00"],
            ["", "", "", "", ""],
            ["Mouse", "Wireless Mouse - Black", "2", "$25.99", "$51.98"],
            ["", "", "", "", ""],
            ["Keyboard", "Mechanical Keyboard - RGB", "1", "$89.99", "$89.99"],
            ["", "", "", "", ""],
            ["Monitor", "24\" LED Monitor", "1", "$179.99", "$179.99"],
            ["", "", "", "", ""],
            ["Cables", "USB-C to USB-A (3-pack)", "1", "$19.99", "$19.99"],
            ["", "", "", "", ""],
            ["Case", "Laptop Sleeve - 13\"", "1", "$24.99", "$24.99"],
            ["", "", "", "", ""],
            ["", "", "", "", ""],
            ["", "", "", "Subtotal:", "$1,365.94"],
            ["", "", "", "Tax (9.5%):", "$129.76"],
            ["", "", "", "Total:", "$1,495.70"]
        ]
        
        items_table = Table(items_data, colWidths=[0.8*inch, 3*inch, 0.6*inch, 0.8*inch, 0.9*inch])
        
        items_table.setStyle(TableStyle([
            # Header styling
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 12),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor('#2E4057')),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            ('LINEBELOW', (0, 0), (-1, 0), 1, colors.HexColor('#4A5568')),
            
            # Data rows
            ('FONTNAME', (0, 2), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 2), (-1, -4), 11),
            ('TEXTCOLOR', (0, 2), (-1, -4), colors.HexColor('#1A252F')),
            
            # Alignment
            ('ALIGN', (0, 2), (0, -1), 'LEFT'),
            ('ALIGN', (1, 2), (1, -1), 'LEFT'),
            ('ALIGN', (2, 2), (2, -1), 'CENTER'),
            ('ALIGN', (3, 2), (-1, -1), 'RIGHT'),
            
            # Add lines under item rows to simulate form lines
            ('LINEBELOW', (0, 2), (-1, 2), 0.5, colors.HexColor('#E2E8F0')),
            ('LINEBELOW', (0, 4), (-1, 4), 0.5, colors.HexColor('#E2E8F0')),
            ('LINEBELOW', (0, 6), (-1, 6), 0.5, colors.HexColor('#E2E8F0')),
            ('LINEBELOW', (0, 8), (-1, 8), 0.5, colors.HexColor('#E2E8F0')),
            ('LINEBELOW', (0, 10), (-1, 10), 0.5, colors.HexColor('#E2E8F0')),
            ('LINEBELOW', (0, 12), (-1, 12), 0.5, colors.HexColor('#E2E8F0')),
            
            # Totals section
            ('FONTNAME', (3, 15), (-1, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (3, 15), (-1, -1), 11),
            ('TEXTCOLOR', (3, 15), (-1, -1), colors.HexColor('#2E4057')),
            
            # Final total highlighting
            ('FONTSIZE', (3, -1), (-1, -1), 14),
            ('TEXTCOLOR', (3, -1), (-1, -1), colors.HexColor('#E53E3E')),
            ('LINEABOVE', (3, -1), (-1, -1), 2, colors.HexColor('#E53E3E')),
            
            # Padding
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ]))
        
        return items_table
    
    def create_footer(self):
        """Create handwritten-style footer"""
        footer_content = []
        
        # Payment info in handwritten style
        payment_text = """
        <b>Payment Instructions:</b><br/>
        💳 Make checks payable to: "Mike's Electronics Store"<br/>
        🏦 Or pay online at: www.mikeselectronics.com/pay<br/>
        📧 Questions? Email: billing@mikeselectronics.com
        """
        
        footer_content.append(Spacer(1, 0.3*inch))
        footer_content.append(Paragraph(payment_text, self.styles['HandwrittenText']))
        footer_content.append(Spacer(1, 0.2*inch))
        
        # Signature line
        signature_data = [
            ["Customer Signature:", "", "Date:", ""],
            ["", "", "", ""]
        ]
        
        signature_table = Table(signature_data, colWidths=[1.5*inch, 2.5*inch, 0.5*inch, 1*inch])
        signature_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.HexColor('#4A5568')),
            ('LINEBELOW', (1, 0), (1, 0), 1, colors.HexColor('#4A5568')),
            ('LINEBELOW', (3, 0), (3, 0), 1, colors.HexColor('#4A5568')),
            ('VALIGN', (0, 0), (-1, -1), 'BOTTOM'),
        ]))
        
        footer_content.append(signature_table)
        footer_content.append(Spacer(1, 0.2*inch))
        
        # Thank you note
        thank_you = "Thank you for your business! 😊"
        footer_content.append(Paragraph(thank_you, 
                                      ParagraphStyle('ThankYou', 
                                                   parent=self.styles['HandwrittenText'],
                                                   alignment=TA_CENTER,
                                                   fontSize=12,
                                                   textColor=colors.HexColor('#2E4057'))))
        
        return footer_content
    
    def generate_invoice(self, filename="handwritten_invoice.pdf"):
        """Generate the handwritten-style invoice PDF"""
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
        story.extend(self.create_header())
        
        # Add invoice info
        story.append(self.create_invoice_info())
        story.append(Spacer(1, 0.3*inch))
        
        # Add items table
        story.append(self.create_items_table())
        
        # Add footer
        story.extend(self.create_footer())
        
        # Build the PDF
        doc.build(story)
        
        return filename


def main():
    """Main function to generate the handwritten invoice"""
    print("✍️  Generating handwritten-style invoice...")
    
    # Create invoice generator
    generator = HandwrittenInvoiceGenerator()
    
    # Generate the invoice
    output_file = "/Users/amgupta/Documents/Snowflake/Demo/handwritten_invoice.pdf"
    generator.generate_invoice(output_file)
    
    print(f"✅ Handwritten invoice generated: {output_file}")
    print(f"📄 File size: {os.path.getsize(output_file) / 1024:.1f} KB")
    
    # Display invoice summary
    print("\n📋 Invoice Summary:")
    print("   Store: Mike's Electronics Store")
    print("   Customer: Jennifer's Coffee Shop")
    print("   Invoice #: 2024-0087")
    print("   Total Amount: $1,495.70")
    print("   Style: Handwritten/Hand-filled form")


if __name__ == "__main__":
    main()
